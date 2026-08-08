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
    @State private var city = Entity()
    @State private var walkSurface = Entity()
    @State private var tableEntity: Entity?
    @State private var showAdjust = false
    @State private var miniatureScale: Float = 1
    @State private var miniatureBuilt = false
    @State private var rigScale: Float = 1
    @State private var insideMode = false
    @State private var insideExtras: Entity?
    @State private var walkPath: WalkPath?
    @State private var walkDistance: Float = 0
    @State private var isWalking = false
    @State private var walkTask: Task<Void, Never>?

    /// Simplified, arc-length-parameterized route in ENU meters.
    struct WalkPath {
        let points: [SIMD2<Float>]
        let cumulative: [Float]
        let headings: [Float]

        var total: Float { cumulative.last ?? 0 }

        func segment(at s: Float) -> Int {
            var index = 0
            for i in 0..<(cumulative.count - 1) where cumulative[i] <= s {
                index = i
            }
            return min(index, headings.count - 1)
        }
    }
    @State private var routeScreenPoints: [CGPoint] = []
    @State private var drawProgress: CGFloat = 0
    @State private var animationTask: Task<Void, Never>?
    @State private var liveTrace: [CGPoint] = []
    @State private var announcedArrival = false
    @State private var handle = Entity()
    @State private var grabOffset: SIMD3<Float>?
    @State private var grabTarget: SIMD3<Float>?
    @State private var grabTask: Task<Void, Never>?

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
            TapGesture()
                .targetedToEntity(walkSurface)
                .onEnded { _ in
                    guard insideMode else { return }
                    isWalking.toggle()
                }
        )
        .gesture(
            DragGesture()
                .targetedToEntity(handle)
                .onChanged { value in
                    guard !insideMode else { return }
                    let location = value.convert(value.location3D, from: .local, to: .scene)
                    if grabOffset == nil {
                        grabOffset = rig.position - location
                        startGrabLoop()
                    }
                    grabTarget = constrainRigPosition(location + (grabOffset ?? .zero))
                }
                .onEnded { _ in
                    grabOffset = nil
                    grabTarget = nil
                    settleTable()
                }
        )
        .onChange(of: exercise.state) { _, newState in
            switch newState {
            case .studying:
                startRouteAnimation()
                appModel.voice.speak(
                    "This is the market at Tiong Bahru. Take your time, and watch the glowing way home. Press I'm ready when you know it."
                )
            case .drawing:
                liveTrace = []
                appModel.voice.speak(
                    exercise.drawMode == .tapCorners
                        ? "Now tap the corners of the way home, one after another."
                        : "Now draw the way home on the table with your finger."
                )
            case .scored:
                appModel.voice.speak(exercise.feedback)
            default:
                break
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

    // MARK: - Calm grab (heavy-object feel, level, clamped, magnetic rest)

    private func buildHandle() {
        let bar = ModelEntity(
            mesh: .generateBox(size: [0.44, 0.03, 0.075], cornerRadius: 0.015),
            materials: [SimpleMaterial(color: UIColor(white: 0.88, alpha: 1), isMetallic: true)]
        )
        handle.addChild(bar)
        handle.position = [0, 0.82, -0.44]
        handle.components.set(CollisionComponent(shapes: [.generateBox(size: [0.54, 0.1, 0.16])]))
        handle.components.set(InputTargetComponent())
        handle.components.set(HoverEffectComponent())
    }

    /// The table eases toward the hand instead of tracking it rigidly —
    /// filters tremor and feels like moving a heavy floating object.
    private func startGrabLoop() {
        grabTask?.cancel()
        grabTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(12))
                guard let target = grabTarget else { return }
                rig.position += (target - rig.position) * 0.12
            }
        }
    }

    /// Keep the table's surface within a comfortable, reachable envelope;
    /// never tilted, never rotated.
    private func constrainRigPosition(_ position: SIMD3<Float>) -> SIMD3<Float> {
        var center = position + rigScale * Self.tablePivot
        center.y = min(max(center.y, 0.05), 1.35)
        let planar = SIMD2(center.x, center.z)
        let radius = simd_length(planar)
        if radius > 0.01 {
            let clamped = min(max(radius, 0.45), 2.3)
            let direction = planar / radius
            center.x = direction.x * clamped
            center.z = direction.y * clamped
        }
        return center - rigScale * Self.tablePivot
    }

    /// On release, gently settle to the nearest sensible height — table
    /// height or on the floor — keeping wherever they placed it laterally.
    private func settleTable() {
        grabTask?.cancel()
        var center = rig.position + rigScale * Self.tablePivot
        center.y = abs(center.y - 0.05) < abs(center.y - 0.85) ? 0.05 : 0.85
        let position = center - rigScale * Self.tablePivot
        rig.move(
            to: Transform(
                scale: SIMD3(repeating: rigScale),
                rotation: rig.orientation,
                translation: position
            ),
            relativeTo: nil,
            duration: 0.45,
            timingFunction: .easeOut
        )
    }

    // MARK: - Caregiver table adjustments

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

    /// Grows the rig until the miniature reaches 1:1 — the patient (seated)
    /// lands at the route start facing along the glowing ribbon, and can
    /// pinch-and-hold to glide home. The map surface and handle hide, and
    /// the height exaggeration animates back to true scale.
    private func stepInside() {
        guard miniatureBuilt, miniatureScale > 0 else { return }
        insideMode = true
        appModel.routeMemoryInside = true
        showAdjust = false
        announcedArrival = false
        grabTask?.cancel()
        grabOffset = nil
        grabTarget = nil
        handle.isEnabled = false
        appModel.voice.speak("Let's stand in the street. Pinch once to walk, and pinch again to rest.")
        tableEntity?.isEnabled = false
        insideExtras?.isEnabled = true
        isWalking = false
        walkDistance = 0
        walkPath = buildWalkPath()

        rig.move(
            to: walkTransform(at: 0),
            relativeTo: nil,
            duration: 1.6,
            timingFunction: .easeInOut
        )
        city.move(
            to: Transform(
                scale: SIMD3(repeating: miniatureScale),
                rotation: city.orientation,
                translation: city.position
            ),
            relativeTo: rig,
            duration: 1.6,
            timingFunction: .easeInOut
        )
        walkTask?.cancel()
        walkTask = Task {
            try? await Task.sleep(for: .seconds(1.7))
            await runWalkLoop()
        }
    }

    private func backToTable() {
        guard miniatureBuilt else { return }
        insideMode = false
        appModel.routeMemoryInside = false
        walkTask?.cancel()
        isWalking = false
        appModel.voice.stop()
        rigScale = 1
        rig.move(to: .identity, relativeTo: nil, duration: 1.2, timingFunction: .easeInOut)
        city.move(
            to: Transform(
                scale: [miniatureScale, miniatureScale * 1.7, miniatureScale],
                rotation: city.orientation,
                translation: city.position
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

    /// Gentle preset placements instead of freeform grabbing.
    private func placeTable(onFloor: Bool) {
        guard !insideMode else { return }
        let offset: SIMD3<Float> = onFloor ? [0, -0.80, 0.2] : .zero
        let position = offset + (1 - rigScale) * Self.tablePivot
        rig.move(
            to: Transform(
                scale: SIMD3(repeating: rigScale),
                rotation: rig.orientation,
                translation: position
            ),
            relativeTo: nil,
            duration: 0.8,
            timingFunction: .easeInOut
        )
    }

    private func resetTable() {
        guard !insideMode else { return }
        rigScale = 1
        rig.move(to: .identity, relativeTo: nil, duration: 0.6, timingFunction: .easeInOut)
    }

    // MARK: - Seated walking

    /// Simplify the route: keep vertices only where the heading changes
    /// meaningfully, so micro-bends don't cause visible snaps.
    private func buildWalkPath() -> WalkPath? {
        let raw = exercise.routePoints.map(NeighborhoodWorld.enu)
        guard raw.count >= 2 else { return nil }

        var points: [SIMD2<Float>] = [raw[0]]
        for i in 1..<(raw.count - 1) {
            guard let last = points.last else { break }
            let d1 = raw[i] - last
            let d2 = raw[i + 1] - raw[i]
            guard simd_length(d1) > 0.3, simd_length(d2) > 0.3 else { continue }
            let turn = normalizedDegrees(heading(of: d2) - heading(of: d1))
            if abs(turn) >= 10 || simd_length(d1) > 30 {
                points.append(raw[i])
            }
        }
        points.append(raw[raw.count - 1])
        guard points.count >= 2 else { return nil }

        var cumulative: [Float] = [0]
        var headings: [Float] = []
        for i in 0..<(points.count - 1) {
            let d = points[i + 1] - points[i]
            cumulative.append(cumulative[i] + simd_length(d))
            headings.append(heading(of: d))
        }
        return WalkPath(points: points, cumulative: cumulative, headings: headings)
    }

    private func heading(of direction: SIMD2<Float>) -> Float {
        atan2(direction.x, -direction.y) * 180 / .pi
    }

    private func normalizedDegrees(_ angle: Float) -> Float {
        var value = angle.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    /// Rig transform that puts route position `s` at the seated patient's
    /// origin with the direction of travel straight ahead.
    private func walkTransform(at s: Float) -> Transform {
        guard let path = walkPath, miniatureBuilt else { return .identity }
        let lifeSize = 1 / miniatureScale
        let segment = path.segment(at: s)
        let a = path.points[segment]
        let b = path.points[segment + 1]
        let segmentLength = max(path.cumulative[segment + 1] - path.cumulative[segment], 0.001)
        let t = min(max((s - path.cumulative[segment]) / segmentLength, 0), 1)
        let p = a + (b - a) * t
        let rotation = simd_quatf(angle: path.headings[segment] * .pi / 180, axis: [0, 1, 0])
        let miniLocal = city.position + miniatureScale * SIMD3(p.x, 0, p.y)
        return Transform(
            scale: SIMD3(repeating: lifeSize),
            rotation: rotation,
            translation: -rotation.act(lifeSize * miniLocal)
        )
    }

    /// 60 Hz glide: constant slow velocity while the pinch is held, tiny
    /// heading changes snap invisibly, sharp corners take a blink turn.
    private func runWalkLoop() async {
        var speed: Float = 0
        while !Task.isCancelled, insideMode {
            try? await Task.sleep(for: .milliseconds(16))
            guard let path = walkPath else { continue }
            let dt: Float = 0.016
            let target: Float = isWalking && walkDistance < path.total ? 1 : 0
            speed += (target - speed) * min(1, dt / 0.15)
            guard speed > 0.02 else { continue }

            let step = speed * 2.2 * dt
            let oldSegment = path.segment(at: walkDistance)
            var s = min(walkDistance + step, path.total)
            if s >= path.total, !announcedArrival {
                announcedArrival = true
                isWalking = false
                appModel.voice.speak("You've reached home. Well done.")
            }
            let newSegment = path.segment(at: s)

            if newSegment > oldSegment {
                let turn = normalizedDegrees(path.headings[newSegment] - path.headings[oldSegment])
                if abs(turn) > 25 {
                    // Blink turn: brief fade instead of a rotating world.
                    s = path.cumulative[newSegment] + 0.01
                    walkDistance = s
                    speed = 0
                    await fadeRig(to: 0, over: 0.12)
                    applyWalkTransform(at: s)
                    await fadeRig(to: 1, over: 0.12)
                    continue
                }
            }
            walkDistance = s
            applyWalkTransform(at: s)
        }
    }

    private func applyWalkTransform(at s: Float) {
        let transform = walkTransform(at: s)
        rig.orientation = transform.rotation
        rig.position = transform.translation
        rig.scale = transform.scale
    }

    private func fadeRig(to opacity: Float, over duration: TimeInterval) async {
        let steps = 6
        let start = rig.components[OpacityComponent.self]?.opacity ?? 1
        for step in 1...steps {
            let progress = Float(step) / Float(steps)
            rig.components.set(OpacityComponent(opacity: start + (opacity - start) * progress))
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) / steps))
        }
    }

    private var tableMap: some View {
        MapReader { proxy in
            Map(position: $camera, interactionModes: []) {
                if exercise.state == .scored, let route = exercise.route {
                    MapPolyline(route.polyline)
                        .stroke(.cyan, lineWidth: 6)
                }
                if exercise.state == .scored, exercise.drawMode == .freeTrace,
                   exercise.drawnPath.count >= 2 {
                    MapPolyline(coordinates: exercise.drawnPath)
                        .stroke(.orange, lineWidth: 6)
                }
                if exercise.state == .drawing, exercise.drawMode == .tapCorners {
                    if exercise.revealedRoute.count >= 2 {
                        MapPolyline(coordinates: exercise.revealedRoute)
                            .stroke(.orange, lineWidth: 7)
                    }
                    ForEach(exercise.cornerTargets) { target in
                        Annotation("", coordinate: target.coordinate) {
                            cornerDot(for: target)
                        }
                    }
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
                        if liveTrace.isEmpty
                            || hypot(
                                value.location.x - liveTrace[liveTrace.count - 1].x,
                                value.location.y - liveTrace[liveTrace.count - 1].y
                            ) > 4 {
                            liveTrace.append(value.location)
                        }
                        if let coordinate = proxy.convert(value.location, from: .local) {
                            exercise.addDrawnPoint(coordinate)
                        }
                    },
                isEnabled: exercise.state == .drawing && exercise.drawMode == .freeTrace
            )
            .overlay {
                // Live ink: raw screen-space stroke, instant under the finger.
                if exercise.state == .drawing, exercise.drawMode == .freeTrace, liveTrace.count >= 2 {
                    RoutePathShape(points: liveTrace)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .allowsHitTesting(false)
                }
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

    private func cornerDot(for target: RouteMemoryExercise.CornerTarget) -> some View {
        let done = target.id < exercise.nextCornerIndex
        let wrong = exercise.lastWrongTapID == target.id
        return Circle()
            .fill(done ? Color.cyan : Color.white.opacity(0.9))
            .frame(width: 36, height: 36)
            .overlay {
                Circle().strokeBorder(
                    Color.orange.opacity(wrong ? 1.0 : 0.7),
                    lineWidth: wrong ? 5 : 2
                )
            }
            .scaleEffect(wrong ? 1.25 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: wrong)
            .animation(.easeOut(duration: 0.25), value: done)
            .onTapGesture {
                exercise.tapCorner(id: target.id)
            }
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

            let miniature = city
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

            // Walking target: pinch the street/ground while inside. Lives in
            // extras so it only exists in life-size mode and can never
            // intercept table-scale or panel input.
            walkSurface.components.set(CollisionComponent(
                shapes: [.generateBox(size: [700, 0.2, 700])]
            ))
            walkSurface.components.set(InputTargetComponent())
            extras.addChild(walkSurface)

            extras.isEnabled = false
            miniature.addChild(extras)
            insideExtras = extras


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
                if insideMode {
                    HStack(spacing: 16) {
                        Button("Back to table") {
                            backToTable()
                        }
                        .font(.title3)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)

                        voiceButton
                    }
                } else {
                    HStack(spacing: 16) {
                        Button("Step inside") {
                            stepInside()
                        }
                        .font(.title3)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                        .disabled(!miniatureBuilt || exercise.state == .drawing)

                        Button {
                            showAdjust.toggle()
                        } label: {
                            Label("Adjust table", systemImage: "slider.horizontal.3")
                                .font(.title3)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)

                        voiceButton
                    }

                    if showAdjust {
                        HStack(spacing: 14) {
                            Button {
                                adjustScale(by: 1 / 1.3)
                            } label: {
                                Label("Smaller", systemImage: "minus.magnifyingglass")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                                    .frame(width: 54, height: 54)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)

                            Button {
                                adjustScale(by: 1.3)
                            } label: {
                                Label("Bigger", systemImage: "plus.magnifyingglass")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                                    .frame(width: 54, height: 54)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)

                            Button("Table height") {
                                placeTable(onFloor: false)
                            }
                            .font(.title3)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)

                            Button("On the floor") {
                                placeTable(onFloor: true)
                            }
                            .font(.title3)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)

                            Button {
                                resetTable()
                            } label: {
                                Label("Reset", systemImage: "arrow.counterclockwise")
                                    .labelStyle(.iconOnly)
                                    .font(.title3)
                                    .frame(width: 54, height: 54)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.circle)

                            Button(exercise.drawMode == .tapCorners ? "Mode: Tap corners" : "Mode: Trace") {
                                exercise.toggleDrawMode()
                            }
                            .font(.title3)
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                        }
                    }
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
            Button("I'm ready") { exercise.startDrawing() }
                .font(.title3)
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(insideMode)

        case .drawing:
            HStack(spacing: 20) {
                Button("Start over") {
                    exercise.clearDrawing()
                    liveTrace = []
                }
                .font(.title3)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                if exercise.drawMode == .freeTrace {
                    Button("I'm done") { exercise.finishDrawing() }
                        .font(.title3)
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.extraLarge)
                        .disabled(exercise.drawnPath.count < 2)
                }
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

    private var voiceButton: some View {
        Button {
            appModel.voice.toggle()
        } label: {
            Label(
                appModel.voice.isEnabled ? "Voice on" : "Voice off",
                systemImage: appModel.voice.isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
            )
            .labelStyle(.iconOnly)
            .font(.title3)
            .frame(width: 54, height: 54)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
    }

    private var prompt: String {
        if insideMode {
            return "Pinch once to walk toward the red pin. Pinch again to rest."
        }
        switch exercise.state {
        case .idle, .loading:
            return "Remember the Way"
        case .failed:
            return "We couldn't load the route right now."
        case .studying:
            return "Take your time. Press I'm ready when you know the way."
        case .drawing:
            return exercise.drawMode == .tapCorners
                ? "Tap the corners of the way home, one after another."
                : "Now draw the way home on the table."
        case .scored:
            return exercise.feedback
        }
    }

}
