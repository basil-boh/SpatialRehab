import MapKit
import RealityKit
import SwiftUI

/// Screen-space polyline for the draw-on route animation; valid because the
/// table camera never moves.
private struct RoutePathShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }
}

/// Route-memory exercise as a holographic table: the interactive 3D Flyover
/// map lies flat at table height in the patient's real room, with a floating
/// control panel behind it. Study the route for 30 seconds, then draw it on
/// the table from memory; the trace is scored against the real route.
struct RouteMemoryTableView: View {
    /// Fixed north-up top-down camera over the route midpoint; a constant
    /// camera keeps the miniature 3D buildings registered to the map surface.
    private static let tableCamera = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 1.28415, longitude: 103.83163),
        distance: 900,
        heading: 0,
        pitch: 0
    )
    private static let mapSize = CGSize(width: 1700, height: 1150)
    /// visionOS attachment views render at ~1360 points per physical meter.
    private static let pointsPerPhysicalMeter: Float = 1360

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    /// Table center in rig-local space; scaling pivots around this point.
    private static let tablePivot = SIMD3<Float>(0, 0.85, -0.95)

    @State private var camera: MapCameraPosition = .camera(RouteMemoryTableView.tableCamera)
    @State private var rig = Entity()
    @State private var handle = Entity()
    @State private var tableEntity: Entity?
    @State private var miniatureEntity: Entity?
    @State private var miniatureScale: Float = 1
    @State private var miniatureBuilt = false
    @State private var rigScale: Float = 1
    @State private var insideMode = false
    @State private var dragOffset: SIMD3<Float>?
    @State private var magnifyStartScale: Float?
    @State private var insideExtras: Entity?
    @State private var routeScreenPoints: [CGPoint] = []
    @State private var drawProgress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?

    private var exercise: RouteMemoryExercise { appModel.routeMemory }

    var body: some View {
        RealityView { content, attachments in
            content.add(rig)
            if let table = attachments.entity(for: "tableMap") {
                table.position = Self.tablePivot
                table.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
                rig.addChild(table)
                tableEntity = table
            }
            buildHandle()
            rig.addChild(handle)
            if let controls = attachments.entity(for: "controls") {
                controls.position = [0, 1.45, -1.65]
                content.add(controls)
            }
        } attachments: {
            Attachment(id: "tableMap") { tableMap }
            Attachment(id: "controls") { controlPanel }
        }
        .gesture(
            DragGesture()
                .targetedToEntity(handle)
                .onChanged { value in
                    guard !insideMode else { return }
                    let location = value.convert(value.location3D, from: .local, to: .scene)
                    if dragOffset == nil {
                        dragOffset = rig.position - location
                    }
                    rig.position = location + (dragOffset ?? .zero)
                }
                .onEnded { _ in
                    dragOffset = nil
                }
        )
        .gesture(
            MagnifyGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    guard !insideMode else { return }
                    if magnifyStartScale == nil {
                        magnifyStartScale = rigScale
                    }
                    setRigScale(min(max((magnifyStartScale ?? 1) * Float(value.magnification), 0.3), 3))
                }
                .onEnded { _ in
                    magnifyStartScale = nil
                }
        )
        .onChange(of: exercise.state) { _, newState in
            if newState == .studying {
                startRouteAnimation()
            }
            // The buildings' input target would intercept gaze meant for
            // drawing on the map beneath them.
            if newState == .drawing {
                miniatureEntity?.components.remove(InputTargetComponent.self)
            } else {
                miniatureEntity?.components.set(InputTargetComponent())
            }
        }
        .onDisappear {
            animationTask?.cancel()
            appModel.routeMemory.stop()
            appModel.routeMemoryInside = false
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    private func buildHandle() {
        let bar = ModelEntity(
            mesh: .generateBox(size: [0.42, 0.028, 0.07], cornerRadius: 0.014),
            materials: [SimpleMaterial(color: UIColor(white: 0.85, alpha: 1), isMetallic: true)]
        )
        handle.addChild(bar)
        handle.position = [0, 0.82, -0.46]
        handle.components.set(CollisionComponent(shapes: [.generateBox(size: [0.5, 0.09, 0.14])]))
        handle.components.set(InputTargetComponent())
        handle.components.set(HoverEffectComponent())
    }

    // MARK: - Scale and life-size

    /// Live scale about the table center; used by both the pinch gesture and
    /// the buttons.
    private func setRigScale(_ newScale: Float) {
        let pivotWorld = rig.position + rigScale * Self.tablePivot
        rig.scale = SIMD3(repeating: newScale)
        rig.position = pivotWorld - newScale * Self.tablePivot
        rigScale = newScale
    }

    private func adjustScale(by factor: Float) {
        guard !insideMode else { return }
        let newScale = min(max(rigScale * factor, 0.3), 3)
        let pivotWorld = rig.position + rigScale * Self.tablePivot
        let newPosition = pivotWorld - newScale * Self.tablePivot
        rigScale = newScale
        rig.move(
            to: Transform(
                scale: SIMD3(repeating: newScale),
                rotation: rig.orientation,
                translation: newPosition
            ),
            relativeTo: nil,
            duration: 0.35,
            timingFunction: .easeInOut
        )
    }

    /// Grows the rig until the miniature reaches 1:1 — the patient stands in
    /// the life-size neighborhood, route start at their feet, roads and the
    /// glowing route on their real floor. The map surface and handle hide
    /// (the map texture cannot survive that magnification), and the height
    /// exaggeration animates back to true scale.
    private func stepInside() {
        guard let miniature = miniatureEntity, miniatureScale > 0 else { return }
        insideMode = true
        appModel.routeMemoryInside = true
        tableEntity?.isEnabled = false
        handle.isEnabled = false
        insideExtras?.isEnabled = true
        let lifeSize = 1 / miniatureScale
        let target = SIMD3<Float>(0, 0, -1.5)
        let newPosition = target - lifeSize * miniature.position
        rig.move(
            to: Transform(
                scale: SIMD3(repeating: lifeSize),
                rotation: rig.orientation,
                translation: newPosition
            ),
            relativeTo: nil,
            duration: 1.6,
            timingFunction: .easeInOut
        )
        miniature.move(
            to: Transform(
                scale: SIMD3(repeating: miniatureScale),
                rotation: miniature.orientation,
                translation: miniature.position
            ),
            relativeTo: rig,
            duration: 1.6,
            timingFunction: .easeInOut
        )
    }

    private func backToTable() {
        guard let miniature = miniatureEntity else { return }
        insideMode = false
        appModel.routeMemoryInside = false
        rigScale = 1
        rig.move(to: .identity, relativeTo: nil, duration: 1.2, timingFunction: .easeInOut)
        miniature.move(
            to: Transform(
                scale: [miniatureScale, miniatureScale * 1.7, miniatureScale],
                rotation: miniature.orientation,
                translation: miniature.position
            ),
            relativeTo: rig,
            duration: 1.2,
            timingFunction: .easeInOut
        )
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            insideExtras?.isEnabled = false
            tableEntity?.isEnabled = true
            handle.isEnabled = true
        }
    }

    private var tableMap: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: []) {
                if exercise.state == .scored, let route = exercise.route {
                    MapPolyline(route.polyline)
                        .stroke(.cyan, lineWidth: 6)
                }
                if exercise.drawnPath.count >= 2 {
                    MapPolyline(coordinates: exercise.drawnPath)
                        .stroke(.orange, lineWidth: 6)
                }
                Marker("Market", systemImage: "basket.fill", coordinate: FindHomeExercise.start)
                    .tint(.green)
                Marker("Home", systemImage: "house.fill", coordinate: FindHomeExercise.home)
                    .tint(.orange)
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if let coordinate = proxy.convert(value.location, from: .local) {
                            exercise.addDrawnPoint(coordinate)
                        }
                    },
                isEnabled: exercise.state == .drawing
            )
            .overlay {
                if exercise.state == .studying, routeScreenPoints.count >= 2 {
                    RoutePathShape(points: routeScreenPoints)
                        .trim(from: 0, to: drawProgress)
                        .stroke(.cyan, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
                        .shadow(color: .cyan.opacity(0.8), radius: 8)
                        .allowsHitTesting(false)
                    if drawProgress > 0, drawProgress < 1, let head = pointAlongRoute(drawProgress) {
                        Circle()
                            .fill(.white)
                            .frame(width: 22, height: 22)
                            .shadow(color: .cyan, radius: 12)
                            .position(head)
                            .allowsHitTesting(false)
                    }
                }
            }
            .task {
                await buildMiniature(proxy)
            }
        }
        .frame(width: Self.mapSize.width, height: Self.mapSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 48))
    }

    /// Draws the route out over ~4.5 s with a glowing head, holds, and
    /// repeats while the patient studies — repetition aids encoding.
    private func startRouteAnimation() {
        animationTask?.cancel()
        animationTask = Task {
            while !Task.isCancelled, exercise.state == .studying {
                if routeScreenPoints.count < 2 {
                    try? await Task.sleep(for: .milliseconds(200))
                    continue
                }
                drawProgress = 0
                for step in 0...270 {
                    guard !Task.isCancelled, exercise.state == .studying else { return }
                    let t = CGFloat(step) / 270
                    drawProgress = t * t * (3 - 2 * t)
                    try? await Task.sleep(for: .milliseconds(16))
                }
                try? await Task.sleep(for: .seconds(3.5))
            }
        }
    }

    private func pointAlongRoute(_ progress: CGFloat) -> CGPoint? {
        guard routeScreenPoints.count >= 2 else { return nil }
        var lengths: [CGFloat] = [0]
        for i in 1..<routeScreenPoints.count {
            let a = routeScreenPoints[i - 1]
            let b = routeScreenPoints[i]
            lengths.append(lengths[i - 1] + hypot(b.x - a.x, b.y - a.y))
        }
        guard let total = lengths.last, total > 0 else { return nil }
        let target = total * min(max(progress, 0), 1)
        for i in 1..<lengths.count where lengths[i] >= target {
            let segment = lengths[i] - lengths[i - 1]
            let t = segment > 0 ? (target - lengths[i - 1]) / segment : 0
            let a = routeScreenPoints[i - 1]
            let b = routeScreenPoints[i]
            return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        return routeScreenPoints.last
    }

    /// Registers the OSM building meshes onto the map surface: converts map
    /// coordinates to view points via the proxy, derives the map's scale, and
    /// mounts a miniature 3D city as a child of the table attachment so real
    /// building volumes rise out of the flat map.
    private func buildMiniature(_ proxy: MapProxy) async {
        guard !miniatureBuilt else { return }
        let origin = FindHomeExercise.start
        let originEast = CLLocationCoordinate2D(
            latitude: origin.latitude,
            longitude: origin.longitude + 100 / (111_320 * cos(origin.latitude * .pi / 180))
        )
        let center = CGPoint(x: Self.mapSize.width / 2, y: Self.mapSize.height / 2)

        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(300))
            guard
                let table = tableEntity,
                let originPoint = proxy.convert(origin, to: .local),
                let eastPoint = proxy.convert(originEast, to: .local),
                let topLeft = proxy.convert(CGPoint.zero, from: .local),
                let bottomRight = proxy.convert(
                    CGPoint(x: Self.mapSize.width, y: Self.mapSize.height),
                    from: .local
                )
            else { continue }

            let pointsPerWorldMeter = Float(hypot(
                eastPoint.x - originPoint.x,
                eastPoint.y - originPoint.y
            )) / 100
            guard pointsPerWorldMeter > 0.05, let map = NeighborhoodWorld.load() else { continue }
            guard !exercise.routePoints.isEmpty else { continue }

            routeScreenPoints = exercise.routePoints.compactMap {
                proxy.convert($0, to: .local)
            }

            // Keep only buildings inside the visible map region.
            let minCorner = NeighborhoodWorld.enu(topLeft)
            let maxCorner = NeighborhoodWorld.enu(bottomRight)
            let visible = map.buildings.filter { building in
                guard let first = building.footprint.first else { return false }
                return first.x >= minCorner.x && first.x <= maxCorner.x
                    && first.y >= minCorner.y && first.y <= maxCorner.y
            }
            guard !visible.isEmpty else { continue }

            let miniature = Entity()
            if let walls = await NeighborhoodWorld.wallsEntity(visible) {
                miniature.addChild(walls)
            }
            if let roofs = NeighborhoodWorld.roofsEntity(visible) {
                miniature.addChild(roofs)
            }

            // The full dusk world, shown only in life-size mode where the
            // map surface is hidden and the space goes fully immersive.
            let extras = Entity()
            extras.addChild(await NeighborhoodWorld.groundEntity())
            if let sidewalks = await NeighborhoodWorld.sidewalksEntity(map.roads) {
                extras.addChild(sidewalks)
            }
            if let roads = await NeighborhoodWorld.roadsEntity(map.roads) {
                extras.addChild(roads)
            }
            if let markings = NeighborhoodWorld.laneMarkingsEntity(map.roads) {
                extras.addChild(markings)
            }
            if exercise.routePoints.count >= 2,
               let ribbon = NeighborhoodWorld.ribbonEntity(
                   exercise.routePoints, width: 1.0, y: 0.05, color: .systemCyan
               ) {
                extras.addChild(ribbon)
            }
            extras.addChild(NeighborhoodWorld.lampsEntity(map.roads, map: map))
            extras.addChild(NeighborhoodWorld.treesEntity(map: map))
            if let sky = await NeighborhoodWorld.skyEntity() {
                extras.addChild(sky)
            }
            extras.addChild(NeighborhoodWorld.sunEntity())
            extras.addChild(NeighborhoodWorld.beaconEntity(at: FindHomeExercise.home))
            extras.isEnabled = false
            miniature.addChild(extras)
            insideExtras = extras

            // Two-hand pinch scaling targets the miniature's bounds.
            let bounds = miniature.visualBounds(relativeTo: miniature)
            miniature.components.set(CollisionComponent(
                shapes: [.generateBox(size: bounds.extents).offsetBy(translation: bounds.center)]
            ))
            miniature.components.set(InputTargetComponent())

            let scale = pointsPerWorldMeter / Self.pointsPerPhysicalMeter
            miniature.scale = [scale, scale * 1.7, scale]
            miniature.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            miniature.position = [
                Float(originPoint.x - center.x) / Self.pointsPerPhysicalMeter,
                Float(center.y - originPoint.y) / Self.pointsPerPhysicalMeter,
                0.004,
            ]
            table.addChild(miniature)
            // Reparent to the rig (same world pose) so hiding the map plane
            // in life-size mode leaves the buildings standing.
            miniature.setParent(rig, preservingWorldTransform: true)
            miniatureEntity = miniature
            miniatureScale = scale
            miniatureBuilt = true
            return
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 24) {
            Text(prompt)
                .font(.system(size: 34, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)

            controls

            if exercise.state == .studying || exercise.state == .drawing || exercise.state == .scored {
                HStack(spacing: 16) {
                    Button {
                        adjustScale(by: 1 / 1.35)
                    } label: {
                        Label("Smaller", systemImage: "minus.magnifyingglass")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .frame(width: 60, height: 60)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .disabled(insideMode)

                    Button {
                        adjustScale(by: 1.35)
                    } label: {
                        Label("Bigger", systemImage: "plus.magnifyingglass")
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .frame(width: 60, height: 60)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .disabled(insideMode)

                    Button(insideMode ? "Back to table" : "Step inside") {
                        insideMode ? backToTable() : stepInside()
                    }
                    .font(.title3)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .disabled(!miniatureBuilt || exercise.state == .drawing)
                }
            }
        }
        .padding(36)
        .glassBackgroundEffect()
    }

    @ViewBuilder
    private var controls: some View {
        switch exercise.state {
        case .idle, .loading:
            ProgressView("Preparing the route…")

        case .failed:
            Button("Try again") { exercise.begin() }
                .font(.title3)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)

        case .studying:
            Button("I'm ready to draw") { exercise.startDrawing() }
                .font(.title3)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)

        case .drawing:
            HStack(spacing: 20) {
                Button("Start over") { exercise.clearDrawing() }
                    .font(.title3)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                Button("I'm done") { exercise.finishDrawing() }
                    .font(.title3)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                    .disabled(exercise.drawnPath.count < 2)
            }

        case .scored:
            HStack(spacing: 20) {
                Button("Play again") { exercise.begin() }
                    .font(.title3)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.extraLarge)
                Button("Done") {
                    Task {
                        appModel.phase = .finished
                        await dismissImmersiveSpace()
                    }
                }
                .font(.title3)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
            }
        }
    }

    private var prompt: String {
        switch exercise.state {
        case .idle, .loading:
            return "Remember the Way"
        case .failed:
            return "We couldn't load the route right now."
        case .studying:
            return "Remember the way home — \(exercise.remainingStudySeconds) s"
        case .drawing:
            return "Now draw the way home on the table."
        case .scored:
            return exercise.feedback
        }
    }

}
