import AVFoundation
import RealityKit
import SwiftUI
import UIKit

/// Soft procedural pouring hiss — filtered brown noise, ramped in and out.
@MainActor
final class PourSound {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var prepared = false
    private var isOn = false

    private func prepare() {
        guard !prepared else { return }
        prepared = true
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        let frames: AVAudioFrameCount = 44_100
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        var brown: Float = 0
        var random = SystemRandomNumberGenerator()
        for i in 0..<Int(frames) {
            let white = Float.random(in: -1...1, using: &random)
            brown = (brown + 0.04 * white) / 1.04
            buffer.floatChannelData![0][i] = brown * 2.4
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.volume = 0
        do {
            try engine.start()
        } catch {
            // Calling play() on a node whose engine isn't running raises an
            // uncatchable NSException — stay silent instead of crashing
            // (simulators without an output route hit this).
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        player.play()
    }

    func setPouring(_ pouring: Bool) {
        setLevel(pouring ? 1 : 0)
    }

    /// Proportional pour volume — flow ramps, so should the sound.
    func setLevel(_ level: Float) {
        prepare()
        guard engine.isRunning else { return }
        let clamped = max(0, min(level, 1))
        isOn = clamped > 0.01
        player.volume = 0.35 * clamped
    }

    func shutdown() {
        player.stop()
        engine.stop()
    }
}

/// Continuous pour stream (tapered tube along the real ballistic arc) plus a
/// small pool of splash droplets at the impact point.
@MainActor
final class PourEffects {
    private var segments: [ModelEntity] = []
    private var splashes: [(entity: ModelEntity, velocity: SIMD3<Float>, life: Int)] = []
    private let splashPoolLimit = 14
    private weak var root: Entity?

    func attach(to root: Entity) {
        self.root = root
        for index in 0..<14 {
            let radius = 0.0062 - Float(index) * 0.00016
            let segment = ModelEntity(
                mesh: .generateCylinder(height: 1, radius: radius),
                materials: [PourEffects.waterMaterial]
            )
            segment.isEnabled = false
            root.addChild(segment)
            segments.append(segment)
        }
    }

    static var waterMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.75, green: 0.85, blue: 0.92, alpha: 1))
        material.roughness = .init(floatLiteral: 0.05)
        material.blending = .transparent(opacity: 0.5)
        return material
    }

    static var milkMaterial: RealityKit.Material {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1))
        material.roughness = .init(floatLiteral: 0.25)
        return material
    }

    /// Renders the arc from the spout and returns where it lands.
    /// `width` scales the stream's thickness so flow can ramp in and out.
    func updateStream(
        from spout: SIMD3<Float>,
        velocity: SIMD3<Float>,
        floorY: Float,
        milk: Bool,
        width: Float = 1
    ) -> SIMD3<Float> {
        let gravity: Float = -5.5
        var points: [SIMD3<Float>] = []
        var t: Float = 0
        var impact = spout
        for _ in 0..<40 {
            let p = spout + velocity * t + SIMD3(0, 0.5 * gravity * t * t, 0)
            points.append(p)
            if p.y <= floorY {
                impact = p
                break
            }
            impact = p
            t += 0.02
        }

        let material = milk ? Self.milkMaterial : Self.waterMaterial
        for (index, segment) in segments.enumerated() {
            guard index + 1 < points.count else {
                segment.isEnabled = false
                continue
            }
            let a = points[index]
            let b = points[index + 1]
            let mid = (a + b) / 2
            let direction = b - a
            let length = simd_length(direction)
            guard length > 0.0005 else {
                segment.isEnabled = false
                continue
            }
            segment.isEnabled = true
            segment.model?.materials = [material]
            segment.position = mid
            segment.scale = [width, length, width]
            segment.orientation = simd_quatf(from: [0, 1, 0], to: direction / length)
        }
        return impact
    }

    func hideStream() {
        for segment in segments {
            segment.isEnabled = false
        }
    }

    func spawnSplash(at point: SIMD3<Float>, milk: Bool) {
        guard let root, splashes.count < splashPoolLimit else { return }
        let color = milk
            ? UIColor(red: 0.96, green: 0.94, blue: 0.88, alpha: 1)
            : UIColor(red: 0.8, green: 0.88, blue: 0.93, alpha: 0.85)
        let drop = ModelEntity(
            mesh: .generateSphere(radius: 0.0028),
            materials: [UnlitMaterial(color: color)]
        )
        drop.position = point
        root.addChild(drop)
        let velocity = SIMD3(
            Float.random(in: -0.14...0.14),
            Float.random(in: 0.16...0.3),
            Float.random(in: -0.14...0.14)
        )
        splashes.append((drop, velocity, 11))
    }

    func tickSplashes() {
        var kept: [(ModelEntity, SIMD3<Float>, Int)] = []
        for var splash in splashes {
            splash.life -= 1
            if splash.life <= 0 {
                splash.entity.removeFromParent()
                continue
            }
            splash.velocity.y -= 0.22
            splash.entity.position += splash.velocity * 0.033
            kept.append(splash)
        }
        splashes = kept
    }
}

/// Physical coffee-making driven by the assets' real anatomy: streams pour
/// from each vessel's named spout, the mug's own internal liquid mesh rises
/// and tints, the kettle and jug visibly empty, the sugar bowl's hinged lid
/// opens and its five real cubes tumble out (landing in the mug dissolves
/// them; misses stay on the table), the tin's lid opens for the grounds,
/// and steam curls off the hot water. Ghost demos and voice guide each step.
struct CoffeeActivityView: View {
    struct ItemSpec {
        let step: CoffeeExercise.Step?
        let resource: String
        let tagID: String
        let title: String
        let role: String
        let targetHeight: Float
        let position: SIMD3<Float>
    }

    struct FlyingBit {
        let entity: ModelEntity
        let step: CoffeeExercise.Step
        let isCube: Bool
        var age: Int
    }

    /// A liquid mesh whose base stays put while it fills or drains.
    struct FillMesh {
        let entity: Entity
        let basePositionY: Float
        let pivotToMinY: Float
        let fullScaleY: Float

        func setFraction(_ fraction: Float) {
            let f = max(fraction, 0.015)
            entity.scale.y = fullScaleY * f
            entity.position.y = basePositionY - pivotToMinY * (f - 1)
        }
    }

    static let tableTop: Float = 0.85

    static let specs: [ItemSpec] = [
        ItemSpec(step: nil, resource: "coffee_mug_with_fill_level", tagID: "tag-mug",
                 title: "Your mug", role: "Everything goes in here",
                 targetHeight: 0.11, position: [0, tableTop, -0.72]),
        ItemSpec(step: .water, resource: "water_kettle_with_fill_level", tagID: "tag-water",
                 title: "Kettle", role: "Hot water",
                 targetHeight: 0.24, position: [-0.46, tableTop, -1.0]),
        ItemSpec(step: .coffee, resource: "coffee_tin_with_scoop", tagID: "tag-coffee",
                 title: "Coffee tin", role: "Coffee powder",
                 targetHeight: 0.15, position: [-0.16, tableTop, -1.06]),
        ItemSpec(step: .sugar, resource: "sugar_bowl_with_free_cubes", tagID: "tag-sugar",
                 title: "Sugar bowl", role: "A little sugar",
                 targetHeight: 0.09, position: [0.16, tableTop, -1.06]),
        ItemSpec(step: .milk, resource: "milk_jug_with_fill_level", tagID: "tag-milk",
                 title: "Milk jug", role: "Fresh milk",
                 targetHeight: 0.17, position: [0.46, tableTop, -1.0]),
        ItemSpec(step: .stir, resource: "teaspoon_on_rest", tagID: "tag-spoon",
                 title: "Teaspoon", role: "For stirring",
                 targetHeight: 0.035, position: [0.27, tableTop, -0.72]),
    ]

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var root = Entity()
    @State private var itemEntities: [String: Entity] = [:]
    @State private var itemHeights: [String: Float] = [:]
    @State private var heldIDs: Set<Entity.ID> = []
    @State private var subscriptions: [EventSubscription] = []
    @State private var flyingBits: [FlyingBit] = []
    @State private var caughtGrains = 0
    @State private var caughtCubes = 0
    @State private var fillTicks: [CoffeeExercise.Step: Int] = [:]
    @State private var wrongPourNoted: Set<CoffeeExercise.Step> = []
    @State private var stirAccumulated: Float = 0
    @State private var lastStirAngle: Float?
    @State private var indicators = CoffeeGuidanceIndicators()
    /// When the cue clock for the current step started. Reset on each new step and
    /// again whenever she puts the item back down, so the escalating cues measure
    /// "how long has she been stuck" rather than "how long has this step been open".
    @State private var cueClockStartedAt = Date.now
    @State private var ghost: Entity?
    @State private var ghostTask: Task<Void, Never>?
    @State private var simulationTask: Task<Void, Never>?
    @State private var steamTask: Task<Void, Never>?
    @State private var sceneReady = false
    @State private var effects = PourEffects()
    @State private var pourSound = PourSound()

    // Real anatomy resolved from the assets.
    @State private var spouts: [CoffeeExercise.Step: Entity] = [:]
    @State private var sourceFills: [CoffeeExercise.Step: FillMesh] = [:]
    @State private var mugFill: FillMesh?
    @State private var lids: [CoffeeExercise.Step: (entity: Entity, closed: simd_quatf)] = [:]
    @State private var sugarCubes: [Entity] = []
    @State private var cubeHomes: [(Entity, Transform, Entity)] = []
    @State private var lastCubeTumble = Date.distantPast
    /// Per-vessel pour flow 0…1 — ramps with tilt so nothing snaps on/off.
    @State private var flows: [CoffeeExercise.Step: Float] = [:]

    private var exercise: CoffeeExercise { appModel.coffee }
    private var mugPosition: SIMD3<Float> { Self.specs[0].position }

    /// Identity for the guidance task. The step alone isn't enough: leaving the
    /// chooser doesn't change the step (it stays at `.water` throughout so the home
    /// window can show step 1 of 5), and changing the guidance level has to restart
    /// the cues on a different schedule.
    private var cueKey: String {
        guard sceneReady else { return "idle" }
        switch exercise.phase {
        case .choosingGuidance: return "choosing"
        case .brewing: return "brew-\(exercise.currentStep?.rawValue ?? -1)-\(exercise.guidance.rawValue)"
        case .finished: return "finished"
        }
    }

    /// The item this step is about, if there is one.
    private var currentSpec: ItemSpec? {
        guard exercise.phase == .brewing, let step = exercise.currentStep else { return nil }
        return Self.specs.first { $0.step == step }
    }

    var body: some View {
        RealityView { content, attachments in
            content.add(root)
            buildTable()
            indicators.attach(to: root)
            effects.attach(to: root)
            await loadItems(attachments: attachments)
            if let panel = attachments.entity(for: "coffeePanel") {
                panel.position = [0, 1.5, -1.62]
                content.add(panel)
            }
            subscriptions.append(content.subscribe(to: ManipulationEvents.WillBegin.self) { event in
                Task { @MainActor in
                    heldIDs.insert(event.entity.id)
                    itemPickedUp(event.entity)
                }
            })
            subscriptions.append(content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
                Task { @MainActor in
                    heldIDs.remove(event.entity.id)
                    settle(event.entity)
                }
            })
            startSimulation()
            sceneReady = true
        } attachments: {
            ForEach(Self.specs, id: \.tagID) { spec in
                Attachment(id: spec.tagID) {
                    tagView(for: spec)
                }
            }
            Attachment(id: "coffeePanel") {
                controlPanel
            }
        }
        .task(id: cueKey) {
            guard sceneReady else { return }
            await cueChanged()
        }
        .onDisappear {
            ghostTask?.cancel()
            simulationTask?.cancel()
            steamTask?.cancel()
            pourSound.shutdown()
            appModel.voice.stop()
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    // MARK: - Scene building

    private func buildTable() {
        let wood = SimpleMaterial(
            color: UIColor(red: 0.55, green: 0.38, blue: 0.24, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )
        let top = ModelEntity(
            mesh: .generateBox(size: [1.5, 0.05, 0.85], cornerRadius: 0.02),
            materials: [wood]
        )
        top.position = [0, Self.tableTop - 0.028, -0.9]
        top.components.set(CollisionComponent(shapes: [.generateBox(size: [1.5, 0.05, 0.85])]))
        top.components.set(PhysicsBodyComponent(mode: .static))
        root.addChild(top)

        let legMaterial = SimpleMaterial(
            color: UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )
        for x in [-0.68, 0.68] {
            for z in [-1.28, -0.55] {
                let leg = ModelEntity(mesh: .generateBox(size: [0.06, 0.8, 0.06]), materials: [legMaterial])
                leg.position = [Float(x), 0.4, Float(z)]
                root.addChild(leg)
            }
        }

        let floor = Entity()
        floor.components.set(CollisionComponent(shapes: [.generateBox(size: [6, 0.02, 6])]))
        floor.components.set(PhysicsBodyComponent(mode: .static))
        floor.position = [0, -0.01, -1]
        root.addChild(floor)
    }

    private func loadItems(attachments: RealityViewAttachments) async {
        for spec in Self.specs {
            guard let model = try? await Entity(named: spec.resource) else { continue }
            let bounds = model.visualBounds(relativeTo: nil)
            let scale = spec.targetHeight / max(bounds.extents.y, 0.001)
            model.scale *= SIMD3(repeating: scale)
            let scaled = model.visualBounds(relativeTo: nil)

            let wrapper = Entity()
            wrapper.name = spec.tagID
            model.position = [-scaled.center.x, -scaled.min.y, -scaled.center.z]
            wrapper.addChild(model)
            wrapper.position = spec.position
            let hitSize = SIMD3(
                max(scaled.extents.x + 0.04, 0.09),
                max(scaled.extents.y + 0.04, 0.09),
                max(scaled.extents.z + 0.04, 0.09)
            )
            let shape = ShapeResource.generateBox(size: hitSize)
                .offsetBy(translation: [0, hitSize.y / 2, 0])

            if spec.step != nil {
                ManipulationComponent.configureEntity(
                    wrapper,
                    allowedInputTypes: .all,
                    collisionShapes: [shape]
                )
            } else {
                wrapper.components.set(CollisionComponent(shapes: [shape]))
            }
            root.addChild(wrapper)
            itemEntities[spec.tagID] = wrapper
            itemHeights[spec.tagID] = scaled.extents.y

            if let tag = attachments.entity(for: spec.tagID) {
                tag.position = spec.position + [0, scaled.extents.y + 0.1, 0]
                root.addChild(tag)
            }

            resolveAnatomy(spec: spec, wrapper: wrapper)
        }
    }

    /// Wire up the named parts the asset generator provided.
    private func resolveAnatomy(spec: ItemSpec, wrapper: Entity) {
        switch spec.step {
        case .water:
            if let spout = wrapper.findEntity(named: "pour_spout") {
                spouts[.water] = spout
            }
            if let column = wrapper.findEntity(named: "water_column") {
                sourceFills[.water] = makeFillMesh(column)
            }
        case .milk:
            if let spout = wrapper.findEntity(named: "pour_spout") {
                spouts[.milk] = spout
            }
            if let milk = wrapper.findEntity(named: "milk") {
                sourceFills[.milk] = makeFillMesh(milk)
            }
        case .coffee:
            if let lid = wrapper.findEntity(named: "lid") {
                lids[.coffee] = (lid, lid.orientation)
            }
        case .sugar:
            if let lid = wrapper.findEntity(named: "lid") {
                lids[.sugar] = (lid, lid.orientation)
            }
            for index in 0..<8 {
                if let cube = wrapper.findEntity(named: "sugar_cube_\(index)") {
                    sugarCubes.append(cube)
                    cubeHomes.append((cube, cube.transform, cube.parent ?? wrapper))
                }
            }
        case .stir, nil:
            if spec.tagID == "tag-mug", let coffee = wrapper.findEntity(named: "coffee") {
                let fill = makeFillMesh(coffee)
                fill.setFraction(0)
                mugFill = fill
            }
        }
    }

    private func makeFillMesh(_ entity: Entity) -> FillMesh {
        let bounds = entity.visualBounds(relativeTo: entity.parent)
        return FillMesh(
            entity: entity,
            basePositionY: entity.position.y,
            pivotToMinY: bounds.min.y - entity.position.y,
            fullScaleY: entity.scale.y
        )
    }

    private func firstModel(in entity: Entity) -> ModelEntity? {
        if let model = entity as? ModelEntity, model.model != nil {
            return model
        }
        for child in entity.children {
            if let found = firstModel(in: child) {
                return found
            }
        }
        return nil
    }

    // MARK: - Simulation

    private func startSimulation() {
        simulationTask?.cancel()
        simulationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                tick()
            }
        }
    }

    private func tick() {
        emitFromHeldVessels()
        updateFlyingBits()
        effects.tickSplashes()
        updateStir()
        updateIndicators()
    }

    /// Decides, every frame, which floating cues should be on.
    ///
    /// While she is holding the right item the "pick this up" cues stand down and
    /// the mug ring takes over, so the guidance always answers the question she is
    /// actually facing: first *what*, then *where*.
    private func updateIndicators() {
        guard let spec = currentSpec, let item = itemEntities[spec.tagID] else {
            indicators.hideAll()
            return
        }
        let holding = heldIDs.contains(item.id)
        let elapsed = Date.now.timeIntervalSince(cueClockStartedAt)
        let schedule = exercise.guidance.cueSchedule

        var cues = CoffeeGuidanceIndicators.Cues()
        if holding {
            // Stirring happens in the mug too, so the ring is right for every step.
            cues.mugTarget = true
        } else {
            cues.halo = elapsed >= schedule.halo
            cues.arrow = elapsed >= schedule.arrow
            cues.path = elapsed >= schedule.path
        }

        indicators.update(
            target: item.position(relativeTo: root),
            targetHeight: itemHeights[spec.tagID] ?? 0.12,
            mug: mugPosition,
            tableY: Self.tableTop,
            cues: cues
        )
    }

    private func emitFromHeldVessels() {
        guard exercise.phase == .brewing else {
            effects.hideStream()
            pourSound.setLevel(0)
            return
        }
        var loudestFlow: Float = 0
        for spec in Self.specs {
            guard let step = spec.step, step != .stir else { continue }
            guard let wrapper = itemEntities[spec.tagID] else { continue }

            // Flow ramps toward the tilt-derived target instead of snapping.
            var targetFlow: Float = 0
            var up = SIMD3<Float>(0, 1, 0)
            if heldIDs.contains(wrapper.id) {
                up = wrapper.orientation.act(SIMD3<Float>(0, 1, 0))
                let tilt = acos(max(-1, min(1, simd_dot(up, SIMD3<Float>(0, 1, 0)))))
                targetFlow = min(max((tilt - 0.85) / 0.5, 0), 1)
            }
            var flow = flows[step, default: 0]
            flow += (targetFlow - flow) * (targetFlow > flow ? 0.25 : 0.2)
            flows[step] = flow

            if flow < 0.05 {
                if lids[step] != nil { closeLid(step) }
                continue
            }

            switch step {
            case .water, .milk:
                loudestFlow = max(loudestFlow, flow)
                let spoutPosition = spouts[step]?.position(relativeTo: root)
                    ?? wrapper.position + up * (itemHeights[spec.tagID] ?? 0.15) * 0.6
                let horizontal = SIMD3(up.x, 0, up.z)
                let velocity = horizontal * (0.08 + 0.3 * flow) + SIMD3<Float>(0, -0.1, 0)
                let overMug = simd_length(SIMD2(spoutPosition.x - mugPosition.x, spoutPosition.z - mugPosition.z)) < 0.3
                let impact = effects.updateStream(
                    from: spoutPosition,
                    velocity: velocity,
                    floorY: overMug ? Self.tableTop + 0.02 : Self.tableTop + 0.002,
                    milk: step == .milk,
                    width: 0.3 + 0.7 * flow
                )
                if flow > 0.3 {
                    effects.spawnSplash(at: impact, milk: step == .milk)
                }
                if simd_length(SIMD2(impact.x - mugPosition.x, impact.z - mugPosition.z)) < 0.045 {
                    liquidReceived(step)
                }
                let threshold: Float = step == .water ? 70 : 50
                sourceFills[step]?.setFraction(max(1 - Float(fillTicks[step, default: 0]) / threshold, 0.1))

            case .coffee:
                openLid(.coffee)
                let mouth = wrapper.position + up * (itemHeights[spec.tagID] ?? 0.15) * 0.62
                let grains = Int((flow * 5).rounded())
                for _ in 0..<grains {
                    spawnGrain(at: mouth + [
                        Float.random(in: -0.01...0.01), 0, Float.random(in: -0.01...0.01),
                    ], tipDirection: up)
                }

            case .sugar:
                openLid(.sugar)
                if flow > 0.35 {
                    tumbleNextCube(from: wrapper, up: up)
                }

            case .stir:
                break
            }
        }
        if loudestFlow < 0.05 {
            effects.hideStream()
        }
        pourSound.setLevel(loudestFlow)
    }

    private func openLid(_ step: CoffeeExercise.Step) {
        guard let lid = lids[step] else { return }
        let open = lid.closed * simd_quatf(angle: -1.1, axis: [1, 0, 0])
        if simd_dot(lid.entity.orientation.vector, open.vector) < 0.999 {
            lid.entity.move(
                to: Transform(scale: lid.entity.scale, rotation: open, translation: lid.entity.position),
                relativeTo: lid.entity.parent, duration: 0.3, timingFunction: .easeOut
            )
        }
    }

    private func closeLid(_ step: CoffeeExercise.Step) {
        guard let lid = lids[step] else { return }
        if simd_dot(lid.entity.orientation.vector, lid.closed.vector) < 0.999 {
            lid.entity.move(
                to: Transform(scale: lid.entity.scale, rotation: lid.closed, translation: lid.entity.position),
                relativeTo: lid.entity.parent, duration: 0.4, timingFunction: .easeInOut
            )
        }
    }

    /// One real sugar cube at a time slides out of the tilted bowl.
    private func tumbleNextCube(from wrapper: Entity, up: SIMD3<Float>) {
        guard Date.now.timeIntervalSince(lastCubeTumble) > 0.55 else { return }
        guard let cube = sugarCubes.first(where: { $0.parent !== root }) else { return }
        lastCubeTumble = .now

        cube.setParent(root, preservingWorldTransform: true)
        let bounds = cube.visualBounds(relativeTo: cube)
        cube.components.set(CollisionComponent(shapes: [
            .generateBox(size: bounds.extents).offsetBy(translation: bounds.center)
        ]))
        cube.components.set(PhysicsBodyComponent(
            massProperties: .init(mass: 0.004),
            material: .generate(friction: 0.7, restitution: 0.1),
            mode: .dynamic
        ))
        let horizontal = SIMD3(up.x, 0, up.z)
        cube.components.set(PhysicsMotionComponent(
            linearVelocity: horizontal * 0.22 + SIMD3<Float>(0, -0.05, 0),
            angularVelocity: [Float.random(in: -3...3), Float.random(in: -3...3), 0]
        ))
        if let model = cube as? ModelEntity {
            flyingBits.append(FlyingBit(entity: model, step: .sugar, isCube: true, age: 0))
        } else if let model = firstModel(in: cube) {
            flyingBits.append(FlyingBit(entity: model, step: .sugar, isCube: true, age: 0))
        }
    }

    private func spawnGrain(at position: SIMD3<Float>, tipDirection: SIMD3<Float>) {
        guard flyingBits.count < 70 else { return }
        let grain = ModelEntity(
            mesh: .generateSphere(radius: 0.003),
            materials: [UnlitMaterial(color: UIColor(red: 0.28, green: 0.18, blue: 0.1, alpha: 1))]
        )
        grain.position = position
        grain.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.003)]))
        grain.components.set(PhysicsBodyComponent(
            massProperties: .init(mass: 0.001),
            material: .generate(friction: 0.6, restitution: 0.05),
            mode: .dynamic
        ))
        let horizontal = SIMD3(tipDirection.x, 0, tipDirection.z)
        grain.components.set(PhysicsMotionComponent(linearVelocity: horizontal * 0.18 + SIMD3<Float>(0, -0.15, 0)))
        root.addChild(grain)
        flyingBits.append(FlyingBit(entity: grain, step: .coffee, isCube: false, age: 0))
    }

    private func updateFlyingBits() {
        var kept: [FlyingBit] = []
        for var bit in flyingBits {
            bit.age += 1
            let position = bit.isCube
                ? bit.entity.position(relativeTo: root)
                : bit.entity.position
            let horizontal = simd_length(SIMD2(position.x - mugPosition.x, position.z - mugPosition.z))

            if horizontal < 0.045, position.y > Self.tableTop - 0.01, position.y < Self.tableTop + 0.13 {
                if bit.isCube {
                    dissolveCube(bit.entity)
                    caughtCubes += 1
                    sugarReceived()
                } else {
                    bit.entity.removeFromParent()
                    caughtGrains += 1
                    grainReceived()
                }
                continue
            }
            if bit.isCube {
                // Spilled cubes rest on the table — real, and charming.
                if position.y < 0.02 {
                    bit.entity.removeFromParent()
                    continue
                }
                if bit.age < 900 {
                    kept.append(bit)
                }
                continue
            }
            if bit.age > 90 || position.y < 0.02 {
                bit.entity.removeFromParent()
                continue
            }
            kept.append(bit)
        }
        flyingBits = kept
    }

    private func dissolveCube(_ cube: ModelEntity) {
        cube.components.remove(PhysicsBodyComponent.self)
        cube.components.remove(PhysicsMotionComponent.self)
        cube.move(
            to: Transform(scale: .init(repeating: 0.01), rotation: cube.orientation, translation: mugPosition + [0, 0.06, 0]),
            relativeTo: root, duration: 0.4, timingFunction: .easeIn
        )
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            cube.removeFromParent()
        }
    }

    // MARK: - Ingredient accounting (real mug liquid)

    private func liquidReceived(_ step: CoffeeExercise.Step) {
        fillTicks[step, default: 0] += 1
        applyMugFill()
        let threshold = step == .water ? 70 : 50
        if exercise.isCurrent(step) {
            if fillTicks[step, default: 0] >= threshold {
                appModel.voice.speak(step.praise)
                if step == .water { startSteam() }
                exercise.completeCurrentStep()
            }
        } else {
            noteWrongPour(step)
        }
    }

    private func grainReceived() {
        applyMugFill()
        if exercise.isCurrent(.coffee) {
            if caughtGrains >= 22 {
                appModel.voice.speak(CoffeeExercise.Step.coffee.praise)
                exercise.completeCurrentStep()
            }
        } else {
            noteWrongPour(.coffee)
        }
    }

    private func sugarReceived() {
        if exercise.isCurrent(.sugar) {
            if caughtCubes >= 2 {
                appModel.voice.speak(CoffeeExercise.Step.sugar.praise)
                exercise.completeCurrentStep()
            }
        } else {
            noteWrongPour(.sugar)
        }
    }

    private func noteWrongPour(_ step: CoffeeExercise.Step) {
        guard !wrongPourNoted.contains(step) else { return }
        wrongPourNoted.insert(step)
        exercise.recordWrongPick()
        if let current = exercise.currentStep {
            appModel.voice.speak("Oh — a little went in early. Let's do \(current.itemName) first.")
        }
    }

    /// Drives the mug's OWN internal liquid mesh: level and color.
    private func applyMugFill() {
        guard let mugFill else { return }
        let water = Float(min(fillTicks[.water, default: 0], 84)) / 70
        let milk = Float(min(fillTicks[.milk, default: 0], 60)) / 50
        let coffee = Float(min(caughtGrains, 28)) / 22

        let level = min(0.5 * water + 0.12 * coffee + 0.24 * milk, 0.95)
        mugFill.setFraction(level)

        let coffeeMix = min(coffee, 1)
        let milkMix = min(milk, 1)
        let base = SIMD3<Float>(0.71, 0.76, 0.78)
        let dark = SIMD3<Float>(0.2, 0.13, 0.08)
        let creamy = SIMD3<Float>(0.55, 0.36, 0.2)
        var tint = base + (dark - base) * coffeeMix
        tint += (creamy - tint) * (milkMix * coffeeMix)

        if let model = firstModel(in: mugFill.entity) {
            var material = PhysicallyBasedMaterial()
            material.baseColor = .init(tint: UIColor(
                red: CGFloat(tint.x), green: CGFloat(tint.y), blue: CGFloat(tint.z), alpha: 1
            ))
            material.roughness = .init(floatLiteral: 0.1)
            material.blending = .transparent(opacity: .init(floatLiteral: Float(0.55) + 0.45 * max(coffeeMix, milkMix)))
            model.model?.materials = [material]
        }
    }

    /// Gentle steam wisps over the hot mug.
    private func startSteam() {
        steamTask?.cancel()
        steamTask = Task {
            var wisps: [ModelEntity] = []
            for _ in 0..<4 {
                var material = UnlitMaterial(color: UIColor(white: 1, alpha: 1))
                material.blending = .transparent(opacity: 0.25)
                let wisp = ModelEntity(mesh: .generateSphere(radius: 0.008), materials: [material])
                wisp.isEnabled = false
                root.addChild(wisp)
                wisps.append(wisp)
            }
            var tick = 0
            while !Task.isCancelled, exercise.phase == .brewing || exercise.phase == .finished {
                for (index, wisp) in wisps.enumerated() {
                    let phase = (Float(tick) / 60 + Float(index) / 4).truncatingRemainder(dividingBy: 1)
                    wisp.isEnabled = true
                    wisp.position = mugPosition + [
                        sin(phase * 6 + Float(index)) * 0.012,
                        0.13 + phase * 0.09,
                        cos(phase * 5) * 0.008,
                    ]
                    wisp.scale = SIMD3(repeating: 1 - phase * 0.7)
                }
                tick += 1
                try? await Task.sleep(for: .milliseconds(50))
            }
            for wisp in wisps {
                wisp.removeFromParent()
            }
        }
    }

    private func updateStir() {
        guard exercise.isCurrent(.stir),
              let spoon = itemEntities["tag-spoon"],
              heldIDs.contains(spoon.id)
        else {
            lastStirAngle = nil
            return
        }
        let offset = SIMD2(spoon.position.x - mugPosition.x, spoon.position.z - mugPosition.z)
        guard simd_length(offset) < 0.09, spoon.position.y < Self.tableTop + 0.24 else {
            lastStirAngle = nil
            return
        }
        let angle = atan2(offset.y, offset.x)
        if let last = lastStirAngle {
            var delta = angle - last
            if delta > .pi { delta -= 2 * .pi }
            if delta < -.pi { delta += 2 * .pi }
            stirAccumulated += abs(delta)
            if stirAccumulated > 4 * .pi {
                appModel.voice.speak(CoffeeExercise.Step.stir.praise)
                exercise.completeCurrentStep()
            }
        }
        lastStirAngle = angle
    }

    // MARK: - Pick up & settle

    private func itemPickedUp(_ entity: Entity) {
        guard let spec = Self.specs.first(where: { $0.tagID == entity.name }) else { return }
        if let step = spec.step, exercise.isCurrent(step) {
            // Clear the demonstration but leave its task running: if she sets the
            // item straight back down, the cues should pick up where they left off
            // rather than never coming back.
            removeGhost()
        }
    }

    private func settle(_ entity: Entity) {
        guard itemEntities[entity.name] != nil else { return }
        if let spec = Self.specs.first(where: { $0.tagID == entity.name }),
           let step = spec.step, exercise.isCurrent(step) {
            // Putting the right item down restarts the cue clock, so someone who
            // reaches for it and hesitates gets the full ladder again instead of
            // being dropped straight into a demonstration.
            cueClockStartedAt = .now
        }
        if let spec = Self.specs.first(where: { $0.tagID == entity.name }),
           let step = spec.step, lids[step] != nil {
            closeLid(step)
        }
        let clampedX = min(max(entity.position.x, -0.65), 0.65)
        let clampedZ = min(max(entity.position.z, -1.25), -0.55)
        let target = SIMD3<Float>(clampedX, Self.tableTop, clampedZ)
        // Travel time scales with distance so nothing teleports.
        let duration = TimeInterval(min(0.3 + simd_length(entity.position - target) * 0.9, 0.85))
        entity.move(
            to: Transform(scale: entity.scale, rotation: .init(), translation: target),
            relativeTo: root,
            duration: duration,
            timingFunction: .easeOut
        )
    }

    // MARK: - Guidance

    private func cueChanged() async {
        ghostTask?.cancel()
        removeGhost()
        wrongPourNoted = []
        stirAccumulated = 0
        lastStirAngle = nil
        cueClockStartedAt = .now

        switch exercise.phase {
        case .choosingGuidance:
            // Nothing is demonstrated until she has said how much help she wants.
            indicators.hideAll()

        case .finished:
            indicators.hideAll()
            appModel.voice.speak("Wonderful. You've made a lovely cup of kopi. Enjoy it while it's warm.")

        case .brewing:
            guard let step = exercise.currentStep else { return }
            let level = exercise.guidance
            appModel.voice.speak(level.spokenInstruction(for: step))

            guard let spec = Self.specs.first(where: { $0.step == step }),
                  let item = itemEntities[spec.tagID]
            else { return }

            // The demo waits out the level's delay, then repeats until she picks the
            // item up. `cueClockStartedAt` moves when she puts something down, so a
            // false start pushes the demo back out rather than firing mid-reach.
            ghostTask = Task {
                while !Task.isCancelled, exercise.currentStep == step, exercise.phase == .brewing {
                    let waited = Date.now.timeIntervalSince(cueClockStartedAt)
                    let remaining = level.cueSchedule.demo - waited
                    if remaining > 0 {
                        try? await Task.sleep(for: .seconds(remaining))
                        continue
                    }
                    if heldIDs.contains(item.id) {
                        try? await Task.sleep(for: .seconds(1))
                        continue
                    }
                    await runGhostDemo(item: item, step: step)
                    try? await Task.sleep(for: .seconds(1.6))
                }
            }
        }
    }

    private func runGhostDemo(item: Entity, step: CoffeeExercise.Step) async {
        guard ghost == nil else { return }
        let clone = item.clone(recursive: true)
        clone.components.remove(InputTargetComponent.self)
        clone.components.remove(CollisionComponent.self)
        clone.components.remove(HoverEffectComponent.self)
        clone.components.remove(ManipulationComponent.self)
        clone.components.set(OpacityComponent(opacity: 0))
        clone.position = item.position
        root.addChild(clone)
        ghost = clone
        for step in 1...5 {
            clone.components.set(OpacityComponent(opacity: 0.07 * Float(step)))
            try? await Task.sleep(for: .milliseconds(45))
        }

        let original = Transform(scale: clone.scale, rotation: clone.orientation, translation: clone.position)
        let hover = SIMD3(mugPosition.x, mugPosition.y + 0.26, mugPosition.z + 0.02)
        clone.move(
            to: Transform(scale: original.scale, rotation: original.rotation, translation: hover),
            relativeTo: root, duration: 0.6, timingFunction: .easeInOut
        )
        try? await Task.sleep(for: .milliseconds(650))
        if step == .stir {
            for tick in 0..<28 {
                let angle = Float(tick) / 28 * 4 * .pi
                clone.position = hover + [cos(angle) * 0.035, -0.06, sin(angle) * 0.035]
                try? await Task.sleep(for: .milliseconds(40))
            }
        } else {
            let tilt = original.rotation * simd_quatf(angle: -1.1, axis: [1, 0, 0])
            clone.move(
                to: Transform(scale: original.scale, rotation: tilt, translation: hover),
                relativeTo: root, duration: 0.4, timingFunction: .easeInOut
            )
            try? await Task.sleep(for: .milliseconds(1300))
        }
        clone.move(to: original, relativeTo: root, duration: 0.55, timingFunction: .easeInOut)
        try? await Task.sleep(for: .milliseconds(600))
        for step in (0...4).reversed() {
            clone.components.set(OpacityComponent(opacity: 0.07 * Float(step)))
            try? await Task.sleep(for: .milliseconds(45))
        }
        removeGhost()
    }

    private func removeGhost() {
        ghost?.removeFromParent()
        ghost = nil
    }

    // MARK: - UI

    private func tagView(for spec: ItemSpec) -> some View {
        // Nothing is singled out while she is still choosing how much help she
        // wants: highlighting the kettle would answer the first step for her
        // before she has said she wants it answered.
        let isCurrent = exercise.phase == .brewing
            && spec.step.map(exercise.isCurrent) == true
        return VStack(spacing: 2) {
            Text(spec.title)
                .font(.headline)
            Text(spec.role)
                .font(.caption)
                .foregroundStyle(isCurrent ? .primary : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(isCurrent ? Color.orange.opacity(0.85) : Color.black.opacity(0.35))
        )
        .foregroundStyle(.white)
        .scaleEffect(isCurrent ? 1.18 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isCurrent)
    }

    private var controlPanel: some View {
        VStack(spacing: 20) {
            if exercise.phase == .choosingGuidance {
                guidanceChooser
            } else {
                brewingPanel
            }
        }
        .padding(32)
        .glassBackgroundEffect()
    }

    /// Shown once, before anything is poured. Three ways to be helped, described
    /// by what the app will do rather than by how well she is expected to cope —
    /// "let me try myself" has to read as a preference, never as the hard mode.
    private var guidanceChooser: some View {
        VStack(spacing: 22) {
            VStack(spacing: 8) {
                Text("Before we start")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("How much help would you like?")
                    .font(.system(size: 34, weight: .semibold))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 640)

            HStack(alignment: .top, spacing: 14) {
                ForEach(CoffeeExercise.GuidanceLevel.allCases) { level in
                    Button {
                        chooseGuidance(level)
                    } label: {
                        VStack(spacing: 10) {
                            Image(systemName: level.symbolName)
                                .font(.system(size: 30))
                                .frame(height: 38)
                            Text(level.title)
                                .font(.system(size: 21, weight: .semibold))
                                .multilineTextAlignment(.center)
                            Text(level.detail)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(width: 214)
                        .padding(.vertical, 22)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 26))
                    .accessibilityLabel("\(level.title). \(level.detail)")
                }
            }

            Text("You can change your mind next time. Nothing here is timed or scored.")
                .font(.system(size: 15))
                .foregroundStyle(.tertiary)

            voiceToggle
        }
    }

    private var brewingPanel: some View {
        VStack(spacing: 20) {
            Text(panelPrompt)
                .font(.system(size: 32, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)

            HStack(spacing: 16) {
                if exercise.phase == .finished {
                    Button("Make another") {
                        resetScene()
                        exercise.begin()
                    }
                    .font(.title3)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)

                    Button("Done") {
                        Task {
                            appModel.phase = .finished
                            await dismissImmersiveSpace()
                        }
                    }
                    .font(.title3)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                }

                voiceToggle
            }
        }
    }

    private var voiceToggle: some View {
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

    private var panelPrompt: String {
        if exercise.phase == .finished {
            return "Your kopi is ready. Wonderful work!"
        }
        return exercise.currentStep?.instruction ?? "Your kopi is ready. Wonderful work!"
    }

    private func chooseGuidance(_ level: CoffeeExercise.GuidanceLevel) {
        if let opening = level.openingLine {
            // VoiceGuide queues, so this lands before the first step's instruction
            // that `cueChanged` speaks a moment later.
            appModel.voice.speak(opening)
        }
        cueClockStartedAt = .now
        exercise.startBrewing(with: level)
    }

    private func resetScene() {
        caughtGrains = 0
        caughtCubes = 0
        fillTicks = [:]
        wrongPourNoted = []
        stirAccumulated = 0
        lastStirAngle = nil
        steamTask?.cancel()
        for bit in flyingBits {
            bit.entity.removeFromParent()
        }
        flyingBits = []
        mugFill?.setFraction(0)
        sourceFills[.water]?.setFraction(1)
        sourceFills[.milk]?.setFraction(1)
        for (cube, home, parent) in cubeHomes {
            cube.components.remove(PhysicsBodyComponent.self)
            cube.components.remove(PhysicsMotionComponent.self)
            cube.components.remove(CollisionComponent.self)
            cube.setParent(parent)
            cube.transform = home
        }
        for step in [CoffeeExercise.Step.coffee, .sugar] {
            closeLid(step)
        }
        for spec in Self.specs {
            if let item = itemEntities[spec.tagID] {
                item.move(
                    to: Transform(scale: item.scale, rotation: .init(), translation: spec.position),
                    relativeTo: root, duration: 0.5, timingFunction: .easeInOut
                )
            }
        }
    }
}
