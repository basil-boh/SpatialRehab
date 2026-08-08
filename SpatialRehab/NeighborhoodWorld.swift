import CoreLocation
import Foundation
import MapKit
import RealityKit
import UIKit
import simd

/// Builds a life-size 3D neighborhood mesh from bundled OpenStreetMap data:
/// real building footprints and heights, roads, and the walking route.
/// All surfaces are procedurally textured — no external assets.
@MainActor
enum NeighborhoodWorld {
    struct Building {
        let footprint: [SIMD2<Float>]
        let height: Float
    }

    struct Road {
        let path: [SIMD2<Float>]
        let width: Float
    }

    struct MapData {
        var buildings: [Building] = []
        var roads: [Road] = []
    }

    /// ENU meters relative to the route start; north maps to -z, east to +x.
    static func enu(_ coordinate: CLLocationCoordinate2D) -> SIMD2<Float> {
        let origin = FindHomeExercise.start
        let lat0 = origin.latitude * .pi / 180
        let x = (coordinate.longitude - origin.longitude) * cos(lat0) * 111_320
        let z = -(coordinate.latitude - origin.latitude) * 110_574
        return SIMD2(Float(x), Float(z))
    }

    static func load() -> MapData? {
        guard
            let url = Bundle.main.url(forResource: "TiongBahruMap", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let elements = json["elements"] as? [[String: Any]]
        else { return nil }

        var map = MapData()
        for element in elements {
            guard
                element["type"] as? String == "way",
                let geometry = element["geometry"] as? [[String: Any]]
            else { continue }
            let tags = element["tags"] as? [String: String] ?? [:]
            let points: [SIMD2<Float>] = geometry.compactMap { node in
                guard let lat = node["lat"] as? Double, let lon = node["lon"] as? Double else { return nil }
                return enu(CLLocationCoordinate2D(latitude: lat, longitude: lon))
            }
            guard points.count >= 2 else { continue }

            if tags["building"] != nil {
                var footprint = points
                if let first = footprint.first, let last = footprint.last, simd_distance(first, last) < 0.1 {
                    footprint.removeLast()
                }
                guard footprint.count >= 3 else { continue }
                map.buildings.append(Building(footprint: footprint, height: height(from: tags)))
            } else if let highway = tags["highway"] {
                map.roads.append(Road(path: points, width: roadWidth(for: highway)))
            }
        }
        return map
    }

    private static func height(from tags: [String: String]) -> Float {
        if let raw = tags["height"], let value = Float(raw.replacingOccurrences(of: " m", with: "")) {
            return min(value, 60)
        }
        if let levels = tags["building:levels"], let value = Float(levels) {
            return min(value * 3.1 + 1, 60)
        }
        return 12
    }

    private static func roadWidth(for highway: String) -> Float {
        switch highway {
        case "primary", "trunk": return 9
        case "secondary": return 8
        case "tertiary": return 7
        case "residential", "unclassified": return 5.5
        case "service": return 4
        case "footway", "path", "cycleway", "steps": return 2
        default: return 5
        }
    }

    // MARK: - Textures

    private static func makeTexture(
        width: Int,
        height: Int,
        draw: (CGContext, CGSize) -> Void
    ) async -> TextureResource? {
        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        draw(context, CGSize(width: width, height: height))
        guard let image = context.makeImage() else { return nil }
        return try? await TextureResource(image: image, options: .init(semantic: .color))
    }

    private static func speckle(
        _ ctx: CGContext,
        size: CGSize,
        count: Int,
        seed: UInt64,
        alpha: CGFloat
    ) {
        var random = SeededRandom(state: seed)
        for _ in 0..<count {
            let x = CGFloat.random(in: 0..<size.width, using: &random)
            let y = CGFloat.random(in: 0..<size.height, using: &random)
            let radius = CGFloat.random(in: 0.6...2.2, using: &random)
            let white = CGFloat.random(in: 0...1, using: &random)
            ctx.setFillColor(UIColor(white: white, alpha: alpha).cgColor)
            ctx.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
        }
    }

    /// Tiong Bahru pastel palette; each style is one upper-storey facade tile
    /// (four bays per 12 m, one bay optionally lit, optional balcony rails).
    private static let facadeStyles: [(wall: UIColor, balcony: Bool, litBay: Int)] = [
        (UIColor(red: 0.93, green: 0.89, blue: 0.82, alpha: 1), false, 3),
        (UIColor(red: 0.95, green: 0.94, blue: 0.91, alpha: 1), true, 1),
        (UIColor(red: 0.92, green: 0.88, blue: 0.72, alpha: 1), false, -1),
        (UIColor(red: 0.84, green: 0.90, blue: 0.83, alpha: 1), true, 2),
    ]

    private static func facadeTexture(style: (wall: UIColor, balcony: Bool, litBay: Int)) async -> TextureResource? {
        await makeTexture(width: 1024, height: 256) { ctx, size in
            ctx.setFillColor(style.wall.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            speckle(ctx, size: size, count: 500, seed: 7, alpha: 0.03)

            for bay in 0..<4 {
                let x = CGFloat(bay) * 256
                ctx.setFillColor(UIColor(white: 0.35, alpha: 0.25).cgColor)
                ctx.fill(CGRect(x: x + 58, y: 50, width: 140, height: 166))
                let lit = bay == style.litBay
                let glass = lit
                    ? UIColor(red: 1.0, green: 0.83, blue: 0.52, alpha: 1)
                    : UIColor(red: 0.15, green: 0.19, blue: 0.27, alpha: 1)
                ctx.setFillColor(glass.cgColor)
                ctx.fill(CGRect(x: x + 66, y: 58, width: 124, height: 150))
                // Mullions.
                ctx.setFillColor(UIColor(white: 0.2, alpha: 0.7).cgColor)
                ctx.fill(CGRect(x: x + 126, y: 58, width: 4, height: 150))
                ctx.fill(CGRect(x: x + 66, y: 130, width: 124, height: 4))
                // Sill.
                ctx.setFillColor(UIColor(white: 1, alpha: 0.45).cgColor)
                ctx.fill(CGRect(x: x + 50, y: 38, width: 156, height: 10))
                if style.balcony {
                    ctx.setFillColor(UIColor(white: 0.25, alpha: 0.55).cgColor)
                    for rail in 0..<3 {
                        ctx.fill(CGRect(x: x + 46, y: 190 + CGFloat(rail) * 12, width: 164, height: 3))
                    }
                }
            }
        }
    }

    /// Ground floor: lit shophouse fronts between five-foot-way columns.
    private static func shopfrontTexture() async -> TextureResource? {
        await makeTexture(width: 1024, height: 256) { ctx, size in
            ctx.setFillColor(UIColor(red: 0.88, green: 0.84, blue: 0.77, alpha: 1).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            for bay in 0..<4 {
                let x = CGFloat(bay) * 256
                // Awning band along the top of the strip.
                let awning = bay % 2 == 0
                    ? UIColor(red: 0.72, green: 0.26, blue: 0.24, alpha: 1)
                    : UIColor(red: 0.24, green: 0.42, blue: 0.5, alpha: 1)
                ctx.setFillColor(awning.cgColor)
                ctx.fill(CGRect(x: x + 20, y: 214, width: 216, height: 26))
                // Warm lit shop glass.
                ctx.setFillColor(UIColor(red: 1.0, green: 0.88, blue: 0.66, alpha: 1).cgColor)
                ctx.fill(CGRect(x: x + 34, y: 30, width: 188, height: 176))
                ctx.setFillColor(UIColor(white: 0.18, alpha: 0.8).cgColor)
                ctx.fill(CGRect(x: x + 126, y: 30, width: 5, height: 176))
                if bay == 1 {
                    ctx.setFillColor(UIColor(red: 0.4, green: 0.26, blue: 0.16, alpha: 1).cgColor)
                    ctx.fill(CGRect(x: x + 140, y: 30, width: 74, height: 176))
                }
                // Five-foot-way columns between bays.
                ctx.setFillColor(UIColor(red: 0.8, green: 0.76, blue: 0.68, alpha: 1).cgColor)
                ctx.fill(CGRect(x: x, y: 0, width: 22, height: 256))
                ctx.setFillColor(UIColor(white: 0, alpha: 0.15).cgColor)
                ctx.fill(CGRect(x: x + 18, y: 0, width: 4, height: 256))
            }
        }
    }

    private static func asphaltTexture() async -> TextureResource? {
        await makeTexture(width: 512, height: 512) { ctx, size in
            ctx.setFillColor(UIColor(red: 0.17, green: 0.17, blue: 0.19, alpha: 1).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            speckle(ctx, size: size, count: 1600, seed: 21, alpha: 0.10)
        }
    }

    private static func paverTexture() async -> TextureResource? {
        await makeTexture(width: 512, height: 512) { ctx, size in
            ctx.setFillColor(UIColor(white: 0.62, alpha: 1).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            speckle(ctx, size: size, count: 700, seed: 33, alpha: 0.05)
            ctx.setStrokeColor(UIColor(white: 0.48, alpha: 1).cgColor)
            ctx.setLineWidth(3)
            for line in stride(from: 0, through: 512, by: 128) {
                ctx.move(to: CGPoint(x: CGFloat(line), y: 0))
                ctx.addLine(to: CGPoint(x: CGFloat(line), y: 512))
                ctx.move(to: CGPoint(x: 0, y: CGFloat(line)))
                ctx.addLine(to: CGPoint(x: 512, y: CGFloat(line)))
            }
            ctx.strokePath()
        }
    }

    private static func groundTexture() async -> TextureResource? {
        await makeTexture(width: 512, height: 512) { ctx, size in
            ctx.setFillColor(UIColor(red: 0.3, green: 0.35, blue: 0.28, alpha: 1).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            var random = SeededRandom(state: 44)
            for _ in 0..<40 {
                let x = CGFloat.random(in: -60..<512, using: &random)
                let y = CGFloat.random(in: -60..<512, using: &random)
                let w = CGFloat.random(in: 40...140, using: &random)
                let dark = Bool.random(using: &random)
                ctx.setFillColor(UIColor(
                    red: dark ? 0.26 : 0.34,
                    green: dark ? 0.31 : 0.39,
                    blue: dark ? 0.24 : 0.31,
                    alpha: 0.5
                ).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: w, height: w * 0.7))
            }
        }
    }

    private static func skyTexture() async -> TextureResource? {
        await makeTexture(width: 1024, height: 512) { ctx, size in
            let colors = [
                UIColor(red: 0.09, green: 0.12, blue: 0.26, alpha: 1).cgColor,
                UIColor(red: 0.24, green: 0.24, blue: 0.42, alpha: 1).cgColor,
                UIColor(red: 0.93, green: 0.62, blue: 0.42, alpha: 1).cgColor,
                UIColor(red: 0.24, green: 0.18, blue: 0.24, alpha: 1).cgColor,
            ]
            let gradient = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                colors: colors as CFArray,
                locations: [0, 0.35, 0.52, 0.62]
            )!
            ctx.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: size.height),
                end: .zero,
                options: [.drawsAfterEndLocation]
            )
            // Sun glow low on the horizon.
            let glow = CGGradient(
                colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                colors: [
                    UIColor(red: 1.0, green: 0.85, blue: 0.6, alpha: 0.9).cgColor,
                    UIColor(red: 1.0, green: 0.75, blue: 0.5, alpha: 0).cgColor,
                ] as CFArray,
                locations: [0, 1]
            )!
            let sunCenter = CGPoint(x: size.width * 0.3, y: size.height * 0.49)
            ctx.drawRadialGradient(
                glow,
                startCenter: sunCenter, startRadius: 6,
                endCenter: sunCenter, endRadius: 150,
                options: []
            )
            // Early stars in the upper sky.
            var random = SeededRandom(state: 99)
            for _ in 0..<90 {
                let x = CGFloat.random(in: 0..<size.width, using: &random)
                let y = CGFloat.random(in: size.height * 0.55..<size.height, using: &random)
                let radius = CGFloat.random(in: 0.7...1.8, using: &random)
                ctx.setFillColor(UIColor(white: 1, alpha: CGFloat.random(in: 0.25...0.7, using: &random)).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: radius, height: radius))
            }
        }
    }

    // MARK: - Mesh assembly helpers

    private struct MeshBatch {
        var positions: [SIMD3<Float>] = []
        var uvs: [SIMD2<Float>] = []
        var indices: [UInt32] = []
        var hasUVs = false

        mutating func addQuad(
            _ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>,
            uv: (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)? = nil
        ) {
            let base = UInt32(positions.count)
            positions.append(contentsOf: [a, b, c, d])
            if let uv {
                hasUVs = true
                uvs.append(contentsOf: [uv.0, uv.1, uv.2, uv.3])
            } else if hasUVs {
                uvs.append(contentsOf: [.zero, .zero, .zero, .zero])
            }
            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
            indices.append(contentsOf: [base + 2, base + 1, base, base + 3, base + 2, base])
        }

        func entity(material: RealityKit.Material, name: String) -> ModelEntity? {
            guard !indices.isEmpty else { return nil }
            var descriptor = MeshDescriptor(name: name)
            descriptor.positions = MeshBuffers.Positions(positions)
            if hasUVs, uvs.count == positions.count {
                descriptor.textureCoordinates = MeshBuffers.TextureCoordinates(uvs)
            }
            descriptor.primitives = .triangles(indices)
            guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
            return ModelEntity(mesh: mesh, materials: [material])
        }
    }

    private static func pbr(_ texture: TextureResource?, tint: UIColor = .white, roughness: Float = 0.9) -> RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        if let texture {
            material.baseColor = .init(tint: .white, texture: .init(texture))
        } else {
            material.baseColor = .init(tint: tint)
        }
        material.roughness = .init(floatLiteral: roughness)
        return material
    }

    // MARK: - Buildings

    /// Walls container: a lit shophouse ground strip shared by every building,
    /// plus upper storeys bucketed into four pastel facade styles.
    static func wallsEntity(_ buildings: [Building]) async -> Entity? {
        guard !buildings.isEmpty else { return nil }
        let shopHeight: Float = 3.6

        var shopBatch = MeshBatch()
        var upperBatches = Array(repeating: MeshBatch(), count: facadeStyles.count)

        for (index, building) in buildings.enumerated() {
            let style = index % facadeStyles.count
            let footprint = building.footprint
            let split = min(shopHeight, building.height)
            for i in 0..<footprint.count {
                let a = footprint[i]
                let b = footprint[(i + 1) % footprint.count]
                let length = simd_distance(a, b)
                guard length > 0.05 else { continue }
                let uMax = length / 12.0

                shopBatch.addQuad(
                    SIMD3(a.x, 0, a.y), SIMD3(b.x, 0, b.y),
                    SIMD3(b.x, split, b.y), SIMD3(a.x, split, a.y),
                    uv: (SIMD2(0, 1), SIMD2(uMax, 1), SIMD2(uMax, 0), SIMD2(0, 0))
                )

                if building.height > shopHeight {
                    let vMax = (building.height - shopHeight) / 3.1
                    upperBatches[style].addQuad(
                        SIMD3(a.x, split, a.y), SIMD3(b.x, split, b.y),
                        SIMD3(b.x, building.height, b.y), SIMD3(a.x, building.height, a.y),
                        uv: (SIMD2(0, vMax), SIMD2(uMax, vMax), SIMD2(uMax, 0), SIMD2(0, 0))
                    )
                }
            }
        }

        let container = Entity()
        if let shopTexture = await shopfrontTexture(),
           let shops = shopBatch.entity(material: pbr(shopTexture, roughness: 0.8), name: "shopfronts") {
            container.addChild(shops)
        }
        for (index, style) in facadeStyles.enumerated() {
            let texture = await facadeTexture(style: style)
            if let walls = upperBatches[index].entity(
                material: pbr(texture, tint: style.wall),
                name: "facade-\(index)"
            ) {
                container.addChild(walls)
            }
        }
        return container
    }

    static func roofsEntity(_ buildings: [Building]) -> ModelEntity? {
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for building in buildings {
            let base = UInt32(positions.count)
            for point in building.footprint {
                positions.append(SIMD3(point.x, building.height, point.y))
            }
            for triangle in triangulate(building.footprint) {
                let a = base + UInt32(triangle.0)
                let b = base + UInt32(triangle.1)
                let c = base + UInt32(triangle.2)
                indices.append(contentsOf: [a, b, c, c, b, a])
            }
        }
        guard !indices.isEmpty else { return nil }
        var descriptor = MeshDescriptor(name: "roofs")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return nil }
        return ModelEntity(
            mesh: mesh,
            materials: [pbr(nil, tint: UIColor(white: 0.45, alpha: 1), roughness: 1)]
        )
    }

    // MARK: - Streets

    static func roadsEntity(_ roads: [Road]) async -> ModelEntity? {
        var batch = MeshBatch()
        for road in roads {
            appendRibbon(road.path, width: road.width, y: 0.03, uvPerMeter: 1 / 6.0, to: &batch)
        }
        let texture = await asphaltTexture()
        return batch.entity(material: pbr(texture, roughness: 1), name: "roads")
    }

    /// Dashed center lines along every drivable road.
    static func laneMarkingsEntity(_ roads: [Road]) -> ModelEntity? {
        var batch = MeshBatch()
        for road in roads where road.width >= 5 {
            let path = road.path
            var carry: Float = 0
            for i in 0..<(path.count - 1) {
                let a = path[i]
                let b = path[i + 1]
                let length = simd_distance(a, b)
                guard length > 0.01 else { continue }
                let direction = (b - a) / length
                let perpendicular = SIMD2(-direction.y, direction.x) * 0.07
                var cursor = carry
                while cursor + 2.2 <= length {
                    let s = a + direction * cursor
                    let e = a + direction * (cursor + 2.2)
                    batch.addQuad(
                        SIMD3(s.x - perpendicular.x, 0.045, s.y - perpendicular.y),
                        SIMD3(s.x + perpendicular.x, 0.045, s.y + perpendicular.y),
                        SIMD3(e.x + perpendicular.x, 0.045, e.y + perpendicular.y),
                        SIMD3(e.x - perpendicular.x, 0.045, e.y - perpendicular.y)
                    )
                    cursor += 7.5
                }
                carry = cursor - length
            }
        }
        return batch.entity(material: UnlitMaterial(color: UIColor(white: 0.9, alpha: 1)), name: "laneMarkings")
    }

    static func sidewalksEntity(_ roads: [Road]) async -> ModelEntity? {
        var batch = MeshBatch()
        for road in roads {
            appendRibbon(road.path, width: road.width + 3.2, y: 0.015, uvPerMeter: 1 / 2.0, to: &batch)
        }
        let texture = await paverTexture()
        return batch.entity(material: pbr(texture, roughness: 1), name: "sidewalks")
    }

    static func ribbonEntity(
        _ coordinates: [CLLocationCoordinate2D],
        width: Float,
        y: Float,
        color: UIColor
    ) -> ModelEntity? {
        var batch = MeshBatch()
        appendRibbon(coordinates.map(enu), width: width, y: y, uvPerMeter: nil, to: &batch)
        return batch.entity(material: UnlitMaterial(color: color), name: "ribbon")
    }

    private static func appendRibbon(
        _ path: [SIMD2<Float>],
        width: Float,
        y: Float,
        uvPerMeter: Float?,
        to batch: inout MeshBatch
    ) {
        guard path.count >= 2 else { return }
        var travelled: Float = 0
        for i in 0..<(path.count - 1) {
            let a = path[i]
            let b = path[i + 1]
            let length = simd_distance(a, b)
            guard length > 0.01 else { continue }
            let direction = (b - a) / length
            let perpendicular = SIMD2(-direction.y, direction.x) * (width / 2)
            if let uvPerMeter {
                batch.addQuad(
                    SIMD3(a.x - perpendicular.x, y, a.y - perpendicular.y),
                    SIMD3(a.x + perpendicular.x, y, a.y + perpendicular.y),
                    SIMD3(b.x + perpendicular.x, y, b.y + perpendicular.y),
                    SIMD3(b.x - perpendicular.x, y, b.y - perpendicular.y),
                    uv: (
                        SIMD2(travelled * uvPerMeter, 0),
                        SIMD2(travelled * uvPerMeter, 1),
                        SIMD2((travelled + length) * uvPerMeter, 1),
                        SIMD2((travelled + length) * uvPerMeter, 0)
                    )
                )
            } else {
                batch.addQuad(
                    SIMD3(a.x - perpendicular.x, y, a.y - perpendicular.y),
                    SIMD3(a.x + perpendicular.x, y, a.y + perpendicular.y),
                    SIMD3(b.x + perpendicular.x, y, b.y + perpendicular.y),
                    SIMD3(b.x - perpendicular.x, y, b.y - perpendicular.y)
                )
            }
            travelled += length
        }
    }

    // MARK: - Environment

    static func groundEntity() async -> ModelEntity {
        var material = PhysicallyBasedMaterial()
        if let texture = await groundTexture() {
            material.baseColor = .init(tint: .white, texture: .init(texture))
            material.textureCoordinateTransform = .init(scale: [24, 24])
        } else {
            material.baseColor = .init(tint: UIColor(red: 0.32, green: 0.37, blue: 0.3, alpha: 1))
        }
        material.roughness = .init(floatLiteral: 1.0)
        return ModelEntity(mesh: .generatePlane(width: 700, depth: 700), materials: [material])
    }

    static func skyEntity() async -> ModelEntity? {
        guard let texture = await skyTexture() else { return nil }
        var material = UnlitMaterial()
        material.color = .init(texture: .init(texture))
        let sky = ModelEntity(mesh: .generateSphere(radius: 550), materials: [material])
        sky.scale = [-1, 1, 1]
        return sky
    }

    /// Warm sunset key light plus a cool low fill so shading has depth.
    static func sunEntity() -> Entity {
        let container = Entity()
        let sun = Entity()
        sun.components.set(DirectionalLightComponent(
            color: UIColor(red: 1.0, green: 0.86, blue: 0.7, alpha: 1),
            intensity: 2800
        ))
        sun.orientation = simd_quatf(angle: 0.55, axis: [0, 1, 0]) * simd_quatf(angle: -0.65, axis: [1, 0, 0])
        container.addChild(sun)

        let fill = Entity()
        fill.components.set(DirectionalLightComponent(
            color: UIColor(red: 0.6, green: 0.7, blue: 1.0, alpha: 1),
            intensity: 500
        ))
        fill.orientation = simd_quatf(angle: -2.3, axis: [0, 1, 0]) * simd_quatf(angle: -1.0, axis: [1, 0, 0])
        container.addChild(fill)
        return container
    }

    /// Street lamps along drivable roads: merged dark poles + arms, merged
    /// warm unlit heads. Entity-light-free so any count stays cheap.
    static func lampsEntity(_ roads: [Road], map: MapData) -> Entity {
        var poles = MeshBatch()
        var heads = MeshBatch()
        var side: Float = 1
        var planted = 0

        for road in roads where road.width >= 4.5 {
            let path = road.path
            var carry: Float = 14
            for i in 0..<(path.count - 1) where planted < 140 {
                let a = path[i]
                let b = path[i + 1]
                let length = simd_distance(a, b)
                guard length > 0.01 else { continue }
                let direction = (b - a) / length
                let perpendicular = SIMD2<Float>(-direction.y, direction.x)
                var cursor = carry
                while cursor <= length && planted < 140 {
                    let offset = road.width / 2 + 0.9
                    let base = a + direction * cursor + perpendicular * offset * side
                    if !insideAnyBuilding(base, map: map) {
                        addLamp(at: base, armToward: -perpendicular * side, poles: &poles, heads: &heads)
                        planted += 1
                        side = -side
                    }
                    cursor += 26
                }
                carry = cursor - length
            }
        }

        let container = Entity()
        if let poleEntity = poles.entity(
            material: pbr(nil, tint: UIColor(white: 0.16, alpha: 1), roughness: 0.6),
            name: "lampPoles"
        ) {
            container.addChild(poleEntity)
        }
        if let headEntity = heads.entity(
            material: UnlitMaterial(color: UIColor(red: 1.0, green: 0.85, blue: 0.6, alpha: 1)),
            name: "lampHeads"
        ) {
            container.addChild(headEntity)
        }
        return container
    }

    private static func addLamp(
        at base: SIMD2<Float>,
        armToward: SIMD2<Float>,
        poles: inout MeshBatch,
        heads: inout MeshBatch
    ) {
        addBox(center: SIMD3(base.x, 2.2, base.y), size: [0.1, 4.4, 0.1], to: &poles)
        let armEnd = base + armToward * 0.8
        addBox(
            center: SIMD3((base.x + armEnd.x) / 2, 4.35, (base.y + armEnd.y) / 2),
            size: [max(abs(armToward.x) * 0.8, 0.08), 0.07, max(abs(armToward.y) * 0.8, 0.08)],
            to: &poles
        )
        addBox(center: SIMD3(armEnd.x, 4.22, armEnd.y), size: [0.24, 0.14, 0.24], to: &heads)
    }

    private static func addBox(center: SIMD3<Float>, size: SIMD3<Float>, to batch: inout MeshBatch) {
        let h = size / 2
        let corners = [
            center + SIMD3(-h.x, -h.y, -h.z), center + SIMD3(h.x, -h.y, -h.z),
            center + SIMD3(h.x, -h.y, h.z), center + SIMD3(-h.x, -h.y, h.z),
            center + SIMD3(-h.x, h.y, -h.z), center + SIMD3(h.x, h.y, -h.z),
            center + SIMD3(h.x, h.y, h.z), center + SIMD3(-h.x, h.y, h.z),
        ]
        batch.addQuad(corners[0], corners[1], corners[5], corners[4])
        batch.addQuad(corners[1], corners[2], corners[6], corners[5])
        batch.addQuad(corners[2], corners[3], corners[7], corners[6])
        batch.addQuad(corners[3], corners[0], corners[4], corners[7])
        batch.addQuad(corners[4], corners[5], corners[6], corners[7])
    }

    /// Street trees on seeded positions, rejected when they land in a
    /// building or on a road; varied heights and canopies.
    static func treesEntity(map: MapData) -> Entity {
        let container = Entity()
        var random = SeededRandom(state: 0x5EED_50_1234)
        let trunkMaterial = SimpleMaterial(color: UIColor(red: 0.36, green: 0.27, blue: 0.2, alpha: 1), roughness: 1, isMetallic: false)
        let leafMaterials = [
            SimpleMaterial(color: UIColor(red: 0.18, green: 0.34, blue: 0.2, alpha: 1), roughness: 1, isMetallic: false),
            SimpleMaterial(color: UIColor(red: 0.26, green: 0.44, blue: 0.24, alpha: 1), roughness: 1, isMetallic: false),
            SimpleMaterial(color: UIColor(red: 0.33, green: 0.42, blue: 0.18, alpha: 1), roughness: 1, isMetallic: false),
        ]

        var planted = 0
        var attempts = 0
        while planted < 60 && attempts < 600 {
            attempts += 1
            let position = SIMD2<Float>(
                Float.random(in: -240...240, using: &random),
                Float.random(in: -240...240, using: &random)
            )
            guard !isBlocked(position, map: map) else { continue }
            planted += 1

            let height = Float.random(in: 2.4...3.8, using: &random)
            let tree = Entity()
            let trunk = ModelEntity(mesh: .generateCylinder(height: height, radius: 0.13), materials: [trunkMaterial])
            trunk.position = [0, height / 2, 0]
            tree.addChild(trunk)

            let material = leafMaterials[planted % leafMaterials.count]
            let mainRadius = Float.random(in: 1.2...1.8, using: &random)
            let canopy = ModelEntity(mesh: .generateSphere(radius: mainRadius), materials: [material])
            canopy.position = [0, height + mainRadius * 0.45, 0]
            canopy.scale = [1, Float.random(in: 0.75...0.95, using: &random), 1]
            tree.addChild(canopy)

            let tuft = ModelEntity(mesh: .generateSphere(radius: mainRadius * 0.6), materials: [material])
            tuft.position = [
                Float.random(in: -0.6...0.6, using: &random),
                height + mainRadius * 0.9,
                Float.random(in: -0.6...0.6, using: &random),
            ]
            tree.addChild(tuft)

            tree.position = [position.x, 0, position.y]
            container.addChild(tree)
        }
        return container
    }

    /// Classic map pin floating above the destination, visible over the
    /// rooftops, with a faint light column so it can be found from anywhere.
    static func beaconEntity(at coordinate: CLLocationCoordinate2D) -> Entity {
        let position = enu(coordinate)
        let container = Entity()

        let pinRed = UnlitMaterial(color: UIColor(red: 1.0, green: 0.23, blue: 0.19, alpha: 1))
        let tip = ModelEntity(mesh: .generateCone(height: 5.2, radius: 1.7), materials: [pinRed])
        tip.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])
        tip.position = [position.x, 20.6, position.y]
        container.addChild(tip)

        let head = ModelEntity(mesh: .generateSphere(radius: 2.5), materials: [pinRed])
        head.position = [position.x, 24.6, position.y]
        container.addChild(head)

        let dot = ModelEntity(
            mesh: .generateSphere(radius: 0.9),
            materials: [UnlitMaterial(color: .white)]
        )
        dot.position = [position.x, 24.6, position.y - 2.0]
        container.addChild(dot)

        var columnMaterial = UnlitMaterial(color: UIColor(red: 1.0, green: 0.35, blue: 0.3, alpha: 1))
        columnMaterial.blending = .transparent(opacity: 0.22)
        let column = ModelEntity(mesh: .generateCylinder(height: 60, radius: 0.9), materials: [columnMaterial])
        column.position = [position.x, 30, position.y]
        container.addChild(column)

        return container
    }

    // MARK: - Geometry utilities

    private static func insideAnyBuilding(_ point: SIMD2<Float>, map: MapData) -> Bool {
        for building in map.buildings where pointInPolygon(point, building.footprint) {
            return true
        }
        return false
    }

    private static func isBlocked(_ point: SIMD2<Float>, map: MapData) -> Bool {
        if insideAnyBuilding(point, map: map) { return true }
        for road in map.roads {
            let clearance = road.width / 2 + 2.2
            for i in 0..<(road.path.count - 1) {
                let a = road.path[i]
                let b = road.path[i + 1]
                let ab = b - a
                let t = max(0, min(1, simd_dot(point - a, ab) / max(simd_length_squared(ab), 0.001)))
                if simd_distance(point, a + ab * t) < clearance { return true }
            }
        }
        return false
    }

    private static func pointInPolygon(_ point: SIMD2<Float>, _ polygon: [SIMD2<Float>]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[j]
            if (a.y > point.y) != (b.y > point.y),
               point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x {
                inside.toggle()
            }
            j = i
        }
        return inside
    }

    /// Ear clipping with a fan fallback; enough for OSM footprints.
    private static func triangulate(_ polygon: [SIMD2<Float>]) -> [(Int, Int, Int)] {
        var result: [(Int, Int, Int)] = []
        var vertices = Array(polygon.indices)

        var signedArea: Float = 0
        for i in polygon.indices {
            let j = (i + 1) % polygon.count
            signedArea += polygon[i].x * polygon[j].y - polygon[j].x * polygon[i].y
        }
        if signedArea < 0 { vertices.reverse() }

        var attempts = 0
        while vertices.count > 3 && attempts < 2000 {
            attempts += 1
            var clipped = false
            for k in vertices.indices {
                let prev = vertices[(k + vertices.count - 1) % vertices.count]
                let curr = vertices[k]
                let next = vertices[(k + 1) % vertices.count]
                let a = polygon[prev], b = polygon[curr], c = polygon[next]
                let cross = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
                if cross <= 0 { continue }
                var blocked = false
                for other in vertices where other != prev && other != curr && other != next {
                    if pointInTriangle(polygon[other], a, b, c) {
                        blocked = true
                        break
                    }
                }
                if blocked { continue }
                result.append((prev, curr, next))
                vertices.remove(at: k)
                clipped = true
                break
            }
            if !clipped { break }
        }

        if vertices.count == 3 {
            result.append((vertices[0], vertices[1], vertices[2]))
        }
        if result.isEmpty && polygon.count >= 3 {
            for i in 1..<(polygon.count - 1) { result.append((0, i, i + 1)) }
        }
        return result
    }

    private static func pointInTriangle(
        _ p: SIMD2<Float>,
        _ a: SIMD2<Float>,
        _ b: SIMD2<Float>,
        _ c: SIMD2<Float>
    ) -> Bool {
        func sign(_ p1: SIMD2<Float>, _ p2: SIMD2<Float>, _ p3: SIMD2<Float>) -> Float {
            (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y)
        }
        let d1 = sign(p, a, b)
        let d2 = sign(p, b, c)
        let d3 = sign(p, c, a)
        let hasNegative = d1 < 0 || d2 < 0 || d3 < 0
        let hasPositive = d1 > 0 || d2 > 0 || d3 > 0
        return !(hasNegative && hasPositive)
    }

    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}

/// Owns the neighborhood scene graph and moves the world so the patient
/// stands at each junction, facing their direction of travel.
@MainActor
final class NeighborhoodController {
    let root = Entity()
    private let world = Entity()
    private var routeLegs: [ModelEntity] = []
    private var built = false

    func buildIfNeeded(route: MKRoute?) async {
        guard !built, let route, let map = NeighborhoodWorld.load() else { return }
        built = true

        world.addChild(await NeighborhoodWorld.groundEntity())
        if let sidewalks = await NeighborhoodWorld.sidewalksEntity(map.roads) {
            world.addChild(sidewalks)
        }
        if let roads = await NeighborhoodWorld.roadsEntity(map.roads) {
            world.addChild(roads)
        }
        if let markings = NeighborhoodWorld.laneMarkingsEntity(map.roads) {
            world.addChild(markings)
        }
        if let walls = await NeighborhoodWorld.wallsEntity(map.buildings) {
            world.addChild(walls)
        }
        if let roofs = NeighborhoodWorld.roofsEntity(map.buildings) {
            world.addChild(roofs)
        }
        world.addChild(NeighborhoodWorld.lampsEntity(map.roads, map: map))
        world.addChild(NeighborhoodWorld.treesEntity(map: map))
        if let sky = await NeighborhoodWorld.skyEntity() {
            world.addChild(sky)
        }
        world.addChild(NeighborhoodWorld.sunEntity())
        world.addChild(NeighborhoodWorld.beaconEntity(at: FindHomeExercise.home))

        // One glowing ribbon per route step, revealed only once walked, so the
        // path ahead never gives the answer away.
        for step in route.steps {
            var coords = [CLLocationCoordinate2D](
                repeating: kCLLocationCoordinate2DInvalid,
                count: step.polyline.pointCount
            )
            step.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: step.polyline.pointCount))
            guard
                coords.count >= 2,
                let leg = NeighborhoodWorld.ribbonEntity(coords, width: 1.1, y: 0.06, color: .systemCyan)
            else {
                routeLegs.append(ModelEntity())
                continue
            }
            leg.isEnabled = false
            world.addChild(leg)
            routeLegs.append(leg)
        }

        root.addChild(world)
    }

    func move(
        to coordinate: CLLocationCoordinate2D,
        heading: Double,
        traveledLegs: Int,
        animated: Bool
    ) async {
        if animated {
            await fade(to: 0, over: 0.35)
        }
        for (index, leg) in routeLegs.enumerated() {
            leg.isEnabled = index < traveledLegs
        }
        let target = NeighborhoodWorld.enu(coordinate)
        let rotation = simd_quatf(angle: Float(heading * .pi / 180), axis: [0, 1, 0])
        root.orientation = rotation
        let rotated = rotation.act(SIMD3(target.x, 0, target.y))
        root.position = [-rotated.x, 0, -rotated.z]
        if animated {
            await fade(to: 1, over: 0.35)
        }
    }

    private func fade(to opacity: Float, over duration: TimeInterval) async {
        let steps = 8
        let start = root.components[OpacityComponent.self]?.opacity ?? 1
        for step in 1...steps {
            let progress = Float(step) / Float(steps)
            root.components.set(OpacityComponent(opacity: start + (opacity - start) * progress))
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) / steps))
        }
    }
}
