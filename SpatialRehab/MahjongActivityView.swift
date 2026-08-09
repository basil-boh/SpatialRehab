import RealityKit
import SwiftUI
import UIKit

/// A real mahjong table against the computer. Every tile is a free object:
/// pick up anything, put it anywhere on the felt, and it stays — the game
/// understands ZONES, not slots. Drop a wall tile near your rack and that's
/// your draw; drop one of your tiles in the glowing circle and that's your
/// discard; melds gather themselves. The opening wash responds to the
/// patient's real hands, and the whole table sounds like mahjong.
struct MahjongActivityView: View {
    struct TileManifest: Decodable {
        struct Tile: Decodable {
            let prim: String
            let face: String
        }
        let tiles: [Tile]
    }

    static let tableTop: Float = 0.85
    static let tileSpacing: Float = 0.041
    /// Lying flat, face against the felt. Flip the sign if faces show.
    static let faceDown = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    /// Lying flat, face to the sky.
    static let faceUp = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    /// The near strip in front of the patient's rack counts as "in hand".
    static let handZoneMinZ: Float = -0.80

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var root = Entity()
    @State private var tilesByPrim: [String: Entity] = [:]
    @State private var faceByPrim: [String: String] = [:]
    @State private var primByEntityID: [Entity.ID: String] = [:]
    @State private var tileThickness: Float = 0.014
    @State private var handPrims: [String] = []
    @State private var wallResidents: Set<String> = []
    @State private var lockedPrims: Set<String> = []
    @State private var finalWallTransforms: [String: Transform] = [:]
    @State private var drawGlowPrim: String?
    @State private var discardCount = 0
    @State private var glowRings: [Entity] = []
    @State private var discardZone = Entity()
    @State private var subscriptions: [EventSubscription] = []
    @State private var isResolving = false
    @State private var ceremonyStarted = false
    @State private var playReady = false
    @State private var ceremonyPrompt: String?
    @State private var audio = MahjongAudio()
    @State private var handTracker = HandWashTracker()

    private var exercise: MahjongExercise { appModel.mahjong }

    private let handAnchor = SIMD3<Float>(-0.26, tableTop, -0.60)
    private let discardCenter = SIMD3<Float>(0, tableTop, -0.98)
    private let meldAnchor = SIMD3<Float>(-0.56, tableTop, -0.68)

    var body: some View {
        RealityView { content, attachments in
            content.add(root)
            buildTable()
            buildDiscardZone()
            await loadRacks()
            if let panel = attachments.entity(for: "mahjongPanel") {
                panel.position = [0, 1.52, -1.75]
                content.add(panel)
            }
            subscriptions.append(content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
                Task { @MainActor in
                    tileReleased(event.entity)
                }
            })
        } attachments: {
            Attachment(id: "mahjongPanel") {
                controlPanel
            }
        }
        .task {
            // Ceremony lives OUT of the make closure so a SwiftUI view
            // update can never shred the choreography mid-flight.
            guard !ceremonyStarted else { return }
            ceremonyStarted = true
            await openingCeremony()
        }
        .onDisappear {
            audio.stopWash()
            audio.shutdown()
            handTracker.stop()
            appModel.voice.stop()
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    /// Cancellation-safe pause: returns false if the task died, so the
    /// ceremony can finish deterministically instead of rushing into chaos.
    private func pause(_ milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return true
        } catch {
            return false
        }
    }

    // MARK: - Table dressing

    private func buildTable() {
        let felt = SimpleMaterial(
            color: UIColor(red: 0.13, green: 0.35, blue: 0.25, alpha: 1),
            roughness: 0.9,
            isMetallic: false
        )
        let top = ModelEntity(
            mesh: .generateBox(size: [1.5, 0.05, 1.0], cornerRadius: 0.02),
            materials: [felt]
        )
        top.position = [0, Self.tableTop - 0.028, -0.97]
        root.addChild(top)

        let rim = SimpleMaterial(
            color: UIColor(red: 0.45, green: 0.3, blue: 0.18, alpha: 1),
            roughness: 0.6,
            isMetallic: false
        )
        let rimSpecs: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([1.56, 0.06, 0.04], [0, Self.tableTop - 0.02, -0.46]),
            ([1.56, 0.06, 0.04], [0, Self.tableTop - 0.02, -1.48]),
            ([0.04, 0.06, 1.06], [-0.76, Self.tableTop - 0.02, -0.97]),
            ([0.04, 0.06, 1.06], [0.76, Self.tableTop - 0.02, -0.97]),
        ]
        for (size, position) in rimSpecs {
            let edge = ModelEntity(mesh: .generateBox(size: size, cornerRadius: 0.01), materials: [rim])
            edge.position = position
            root.addChild(edge)
        }

        let legMaterial = SimpleMaterial(
            color: UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )
        for x in [-0.68, 0.68] {
            for z in [-1.42, -0.52] {
                let leg = ModelEntity(mesh: .generateBox(size: [0.06, 0.8, 0.06]), materials: [legMaterial])
                leg.position = [Float(x), 0.4, Float(z)]
                root.addChild(leg)
            }
        }
    }

    private func buildDiscardZone() {
        var material = UnlitMaterial(color: UIColor.cyan.withAlphaComponent(0.3))
        material.blending = .transparent(opacity: 0.3)
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.003, radius: 0.16),
            materials: [material]
        )
        discardZone.addChild(ring)
        discardZone.position = discardCenter
        discardZone.isEnabled = false
        root.addChild(discardZone)
    }

    private func loadRacks() async {
        guard let rackSource = try? await Entity(named: "mahjong_tile_rack") else { return }
        let bounds = rackSource.visualBounds(relativeTo: nil)
        let scale = 0.58 / max(bounds.extents.x, 0.001)
        rackSource.scale *= SIMD3(repeating: scale)
        let scaled = rackSource.visualBounds(relativeTo: nil)

        for (z, yaw) in [(Float(-0.54), Float(0)), (Float(-1.42), Float.pi)] {
            let holder = Entity()
            let rack = rackSource.clone(recursive: true)
            rack.position = [-scaled.center.x, -scaled.min.y, -scaled.center.z]
            holder.addChild(rack)
            holder.position = [0, Self.tableTop, z]
            holder.orientation = simd_quatf(angle: yaw, axis: [0, 1, 0])
            root.addChild(holder)
        }
    }

    // MARK: - Opening ceremony: wash → walls → deal

    private func openingCeremony() async {
        guard
            let manifestURL = Bundle.main.url(forResource: "mahjong_full_set_sg148.tiles", withExtension: "json"),
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(TileManifest.self, from: data),
            let fullSet = try? await Entity(named: "mahjong_full_set_sg148")
        else { return }

        var random = NeighborhoodWorld.SeededRandom(state: UInt64(Date.now.timeIntervalSince1970))

        // Extract by CLONING (the clone path is the one that provably keeps
        // materials); the full set itself never enters the scene.
        var normalizeScale: Float?
        for tile in manifest.tiles {
            let name = String(tile.prim.split(separator: "/").last ?? "")
            guard let source = fullSet.findEntity(named: name) else { continue }
            let model = source.clone(recursive: true)
            if normalizeScale == nil {
                let bounds = model.visualBounds(relativeTo: model)
                normalizeScale = 0.05 / max(bounds.extents.x, bounds.extents.y, bounds.extents.z, 0.001)
            }
            model.scale = SIMD3(repeating: normalizeScale ?? 1)
            model.orientation = .init()
            model.position = .zero
            let scaled = model.visualBounds(relativeTo: nil)
            tileThickness = max(scaled.extents.z, 0.008)

            let wrapper = Entity()
            model.position = [-scaled.center.x, -scaled.min.y, -scaled.center.z]
            wrapper.addChild(model)
            root.addChild(wrapper)
            tilesByPrim[tile.prim] = wrapper
            faceByPrim[tile.prim] = tile.face
            primByEntityID[wrapper.id] = tile.prim
            configureGrab(tile.prim)
        }

        // Destinies first: 13 for the patient (4 pairs + singles), 13 for
        // the computer, everything else to the walls. No orphans, ever.
        var byFace: [String: [String]] = [:]
        for prim in tilesByPrim.keys {
            byFace[faceByPrim[prim] ?? "", default: []].append(prim)
        }
        var hand: [String] = []
        let pairCandidates = byFace.keys.filter { byFace[$0, default: []].count >= 3 }.shuffled(using: &random)
        for face in pairCandidates.prefix(4) {
            hand.append(byFace[face]!.removeFirst())
            hand.append(byFace[face]!.removeFirst())
        }
        for face in byFace.keys.shuffled(using: &random) where hand.count < 13 {
            if let prims = byFace[face], !prims.isEmpty {
                hand.append(byFace[face]!.removeFirst())
            }
        }
        var pool = byFace.values.flatMap { $0 }.shuffled(using: &random)
        let opponentPrims = Array(pool.prefix(13))
        pool.removeFirst(min(13, pool.count))
        let wallOrder = pool
        wallResidents = Set(wallOrder)

        // Precompute EVERY final transform so any interruption can finish
        // the table instantly and correctly.
        var wallSlots: [(SIMD3<Float>, Bool)] = []
        func addStacks(_ base: [SIMD3<Float>]) {
            for position in base {
                wallSlots.append((position + [0, tileThickness, 0], true))
                wallSlots.append((position, false))
            }
        }
        addStacks((0..<15).map { [0.56, Self.tableTop + 0.001, -0.74 - Float($0) * Self.tileSpacing] })
        addStacks((0..<15).map { [-0.56, Self.tableTop + 0.001, -0.74 - Float($0) * Self.tileSpacing] })
        addStacks((0..<16).map { [-0.31 + Float($0) * Self.tileSpacing, Self.tableTop + 0.001, -1.32] })
        var frontStack = 0
        while wallSlots.count < wallOrder.count {
            addStacks([[-0.29 + Float(frontStack) * Self.tileSpacing, Self.tableTop + 0.001, -0.74]])
            frontStack += 1
        }
        for (index, prim) in wallOrder.enumerated() {
            let (position, _) = wallSlots[index]
            finalWallTransforms[prim] = Transform(
                scale: tilesByPrim[prim]?.scale ?? .one,
                rotation: Self.faceDown,
                translation: position
            )
        }
        var finals: [String: Transform] = finalWallTransforms
        let sortedHand = hand.sorted { (faceByPrim[$0] ?? "") < (faceByPrim[$1] ?? "") }
        for (index, prim) in sortedHand.enumerated() {
            finals[prim] = Transform(
                scale: tilesByPrim[prim]?.scale ?? .one,
                rotation: .init(),
                translation: handAnchor + [Float(index) * Self.tileSpacing, 0.001, 0]
            )
        }
        for (index, prim) in opponentPrims.enumerated() {
            finals[prim] = Transform(
                scale: tilesByPrim[prim]?.scale ?? .one,
                rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]),
                translation: [-0.26 + Float(index) * Self.tileSpacing, Self.tableTop + 0.001, -1.38]
            )
        }
        handPrims = sortedHand

        func finishInstantly() {
            for (prim, transform) in finals {
                tilesByPrim[prim]?.transform = transform
            }
            ceremonyPrompt = nil
            exercise.dealt(sortedHand.compactMap { faceByPrim[$0] })
            playReady = true
            beginPlayerDraw()
        }

        // Face-down carpet for the wash — tidy grid, no overlaps.
        let allPrims = Array(tilesByPrim.keys).shuffled(using: &random)
        let center = SIMD2<Float>(0, -0.98)
        var carpet: [String: SIMD2<Float>] = [:]
        for (index, prim) in allPrims.enumerated() {
            let column = index % 13
            let row = index / 13
            let base = SIMD2(Float(column - 6) * 0.046, Float(row - 5) * 0.046 - 0.98)
            carpet[prim] = base
            tilesByPrim[prim]?.position = [base.x, Self.tableTop + 0.001, base.y]
            tilesByPrim[prim]?.orientation = Self.faceDown
        }

        // The wash: real palms push the tiles; ambient swirl underneath.
        ceremonyPrompt = "Wash the tiles with your hands…"
        appModel.voice.speak("First, we wash the tiles. Swish them around with your hands — just like at home.")
        audio.startWash()
        Task { await handTracker.start() }   // never blocks the ceremony

        var positions = carpet
        var lastPushClack = 0
        for tick in 0..<170 {
            guard await pause(33) else {
                audio.stopWash()
                finishInstantly()
                return
            }
            let t = Float(tick) / 170
            let ambient = sin(t * .pi * 2) * 0.4
            let cosA = cos(ambient)
            let sinA = sin(ambient)
            var pushed = false
            for (prim, base) in carpet {
                guard let tile = tilesByPrim[prim], var position = positions[prim] else { continue }
                let offset = base - center
                let home = SIMD2(
                    center.x + offset.x * cosA - offset.y * sinA,
                    center.y + offset.x * sinA + offset.y * cosA
                )
                position += (home - position) * 0.08
                for palm in handTracker.palms {
                    let palmXZ = SIMD2(palm.x, palm.z)
                    let away = position - palmXZ
                    let distance = simd_length(away)
                    if distance < 0.15, distance > 0.001, abs(palm.y - Self.tableTop) < 0.25 {
                        position += (away / distance) * (0.15 - distance) * 0.35
                        pushed = true
                    }
                }
                let fromCenter = position - center
                let radius = simd_length(fromCenter)
                if radius > 0.34 {
                    position = center + fromCenter / radius * 0.34
                }
                positions[prim] = position
                tile.position = [position.x, Self.tableTop + 0.001, position.y]
            }
            if pushed, tick - lastPushClack > 7 {
                lastPushClack = tick
                audio.clack(volume: 0.25)
            }
        }
        audio.stopWash()

        // Walls assemble in waves.
        ceremonyPrompt = "Building the walls…"
        appModel.voice.speak("Now we stack the walls.")
        for (index, prim) in wallOrder.enumerated() {
            guard let tile = tilesByPrim[prim], let transform = finalWallTransforms[prim] else { continue }
            tile.move(to: transform, relativeTo: root, duration: 0.45, timingFunction: .easeInOut)
            if index % 10 == 9 {
                audio.clack(volume: 0.4)
                guard await pause(60) else {
                    finishInstantly()
                    return
                }
            }
        }
        guard await pause(700) else {
            finishInstantly()
            return
        }

        // The deal, tile by tile.
        ceremonyPrompt = "Dealing…"
        appModel.voice.speak("And now we deal. Thirteen tiles for you, thirteen for me.")
        for prim in opponentPrims {
            guard let tile = tilesByPrim[prim], let transform = finals[prim] else { continue }
            tile.move(to: transform, relativeTo: root, duration: 0.4, timingFunction: .easeInOut)
            guard await pause(40) else {
                finishInstantly()
                return
            }
        }
        for prim in sortedHand {
            guard let tile = tilesByPrim[prim], let transform = finals[prim] else { continue }
            tile.move(to: transform, relativeTo: root, duration: 0.4, timingFunction: .easeInOut)
            audio.click()
            guard await pause(60) else {
                finishInstantly()
                return
            }
        }
        _ = await pause(500)

        ceremonyPrompt = nil
        exercise.dealt(sortedHand.compactMap { faceByPrim[$0] })
        playReady = true
        appModel.voice.speak(
            "Collect three of the same tile to make a set — two sets wins. Take any tile from the wall and bring it to your rack. The shining one is lucky."
        )
        beginPlayerDraw()
    }

    // MARK: - Grab

    private func configureGrab(_ prim: String) {
        guard let tile = tilesByPrim[prim], !tile.components.has(ManipulationComponent.self) else { return }
        let bounds = tile.visualBounds(relativeTo: tile)
        let size = SIMD3(
            max(bounds.extents.x + 0.02, 0.05),
            max(bounds.extents.y + 0.02, 0.05),
            max(bounds.extents.z + 0.02, 0.04)
        )
        ManipulationComponent.configureEntity(
            tile,
            allowedInputTypes: .all,
            collisionShapes: [.generateBox(size: size).offsetBy(translation: bounds.center)]
        )
    }

    private func lockTile(_ prim: String) {
        lockedPrims.insert(prim)
        guard let tile = tilesByPrim[prim] else { return }
        tile.components.remove(ManipulationComponent.self)
        tile.components.remove(InputTargetComponent.self)
    }

    // MARK: - Free-placement release logic (zones, not slots)

    private func tileReleased(_ entity: Entity) {
        guard playReady, !isResolving, let prim = primByEntityID[entity.id],
              !lockedPrims.contains(prim)
        else { return }

        let position = entity.position
        let inDiscardCircle = simd_length(SIMD2(
            position.x - discardCenter.x,
            position.z - discardCenter.z
        )) < 0.18
        let inHandZone = position.z > Self.handZoneMinZ && abs(position.x) < 0.72

        if exercise.phase == .playerDraw, wallResidents.contains(prim), inHandZone {
            // They brought a wall tile to their side — that's the draw.
            settleStanding(entity, at: position)
            resolveDraw(prim: prim)
            return
        }
        if exercise.phase == .playerDiscard, handPrims.contains(prim), inDiscardCircle {
            resolveDiscard(prim: prim, tile: entity)
            return
        }

        // Anywhere else: the tile simply rests where they put it, upright,
        // on the felt — like a real table. No snap-backs.
        if wallResidents.contains(prim), !inHandZone {
            // A wandering wall tile lies back face-down wherever it is.
            settleFaceDown(entity, at: position)
        } else {
            settleStanding(entity, at: position)
        }
        if exercise.phase == .playerDiscard, handPrims.contains(prim), !inDiscardCircle {
            exercise.recordWrongDrop()
        }
    }

    private func clampedToFelt(_ position: SIMD3<Float>) -> SIMD3<Float> {
        [
            min(max(position.x, -0.72), 0.72),
            Self.tableTop + 0.001,
            min(max(position.z, -1.44), -0.50),
        ]
    }

    private func settleStanding(_ tile: Entity, at position: SIMD3<Float>) {
        let yaw = simd_quatf(angle: 0, axis: [0, 1, 0])
        tile.move(
            to: Transform(scale: tile.scale, rotation: yaw, translation: clampedToFelt(position)),
            relativeTo: root, duration: 0.3, timingFunction: .easeOut
        )
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            audio.clack(volume: 0.4)
        }
    }

    private func settleFaceDown(_ tile: Entity, at position: SIMD3<Float>) {
        tile.move(
            to: Transform(scale: tile.scale, rotation: Self.faceDown, translation: clampedToFelt(position)),
            relativeTo: root, duration: 0.3, timingFunction: .easeOut
        )
    }

    // MARK: - Turns

    private func beginPlayerDraw() {
        clearGlow()
        discardZone.isEnabled = false
        // Suggest a lucky wall tile (rigged toward their pairs) — but ANY
        // wall tile brought to their side counts.
        let pairFaces = exercise.pairFaces
        let tops = wallResidents.filter { prim in
            guard let transform = finalWallTransforms[prim] else { return false }
            return transform.translation.x > 0.4 || transform.translation.z > -0.9
        }
        drawGlowPrim = tops.first { pairFaces.contains(faceByPrim[$0] ?? "") } ?? tops.first
        if let prim = drawGlowPrim, let tile = tilesByPrim[prim] {
            glow(at: tile.position, radius: 0.05)
        }
    }

    private func resolveDraw(prim: String) {
        isResolving = true
        clearGlow()
        wallResidents.remove(prim)
        handPrims.append(prim)

        let face = faceByPrim[prim] ?? ""
        let melded = exercise.drew(face)

        Task {
            try? await Task.sleep(for: .milliseconds(400))
            audio.clack(volume: 0.6)

            if let meldFace = melded {
                await animateMeld(face: meldFace)
                audio.chime()
                if exercise.phase == .won {
                    isResolving = false
                    appModel.voice.speak("Mahjong! Two sets — you've won the game. Fantastic!")
                    return
                }
                appModel.voice.speak("Three of a kind — a set! Now throw one of your tiles into the glowing circle.")
            } else if exercise.pairFaces.contains(face) {
                appModel.voice.speak("Lovely — that matches tiles you already have. Now throw one you don't need into the circle.")
            } else {
                appModel.voice.speak("That one's yours now. Throw a tile you don't need into the circle.")
            }

            isResolving = false
            beginPlayerDiscard()
        }
    }

    private func animateMeld(face: String) async {
        let meldPrims = Array(handPrims.filter { faceByPrim[$0] == face }.prefix(3))
        let meldIndex = max(exercise.meldsCompleted - 1, 0)
        for (offset, prim) in meldPrims.enumerated() {
            handPrims.removeAll { $0 == prim }
            lockTile(prim)
            guard let tile = tilesByPrim[prim] else { continue }
            let slot = meldAnchor + SIMD3(Float(meldIndex) * 0.16 + Float(offset) * (Self.tileSpacing + 0.004), 0.001, 0)
            tile.move(
                to: Transform(scale: tile.scale, rotation: Self.faceUp, translation: slot),
                relativeTo: root, duration: 0.55, timingFunction: .easeInOut
            )
        }
        try? await Task.sleep(for: .milliseconds(650))
    }

    private func beginPlayerDiscard() {
        guard exercise.phase == .playerDiscard else { return }
        discardZone.isEnabled = true
        if let suggestion = exercise.suggestedDiscard,
           let prim = handPrims.first(where: { faceByPrim[$0] == suggestion }),
           let tile = tilesByPrim[prim] {
            glow(at: tile.position, radius: 0.032)
        }
    }

    private func resolveDiscard(prim: String, tile: Entity) {
        isResolving = true
        clearGlow()
        discardZone.isEnabled = false
        handPrims.removeAll { $0 == prim }
        lockTile(prim)
        exercise.discarded(faceByPrim[prim] ?? "")
        placeInDiscardGrid(tile)

        Task {
            try? await Task.sleep(for: .milliseconds(600))
            await computerTurn()
            isResolving = false
            appModel.voice.speak("Your turn. Take any tile from the wall — the shining one is lucky.")
            beginPlayerDraw()
        }
    }

    private func placeInDiscardGrid(_ tile: Entity) {
        let column = discardCount % 6
        let row = discardCount / 6
        discardCount += 1
        let slot = SIMD3(
            discardCenter.x - 0.11 + Float(column) * 0.045,
            Self.tableTop + 0.002,
            discardCenter.z + 0.07 - Float(row) * 0.055
        )
        tile.move(
            to: Transform(scale: tile.scale, rotation: Self.faceUp, translation: slot),
            relativeTo: root, duration: 0.5, timingFunction: .easeInOut
        )
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            audio.clack(volume: 0.7)
        }
    }

    private func computerTurn() async {
        appModel.voice.speak("My turn.")
        if let prim = wallResidents.first(where: { finalWallTransforms[$0]?.translation.x ?? 0 < -0.4 }) ?? wallResidents.first,
           let tile = tilesByPrim[prim] {
            wallResidents.remove(prim)
            lockTile(prim)
            tile.move(
                to: Transform(
                    scale: tile.scale,
                    rotation: simd_quatf(angle: .pi, axis: [0, 1, 0]),
                    translation: [0.3, Self.tableTop + 0.001, -1.38]
                ),
                relativeTo: root, duration: 0.5, timingFunction: .easeInOut
            )
            try? await Task.sleep(for: .milliseconds(700))
            placeInDiscardGrid(tile)
            try? await Task.sleep(for: .milliseconds(600))
        }
        exercise.computerFinished()
    }

    // MARK: - Glow

    private func glow(at position: SIMD3<Float>, radius: Float) {
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.005, radius: radius + 0.02),
            materials: [UnlitMaterial(color: UIColor.cyan.withAlphaComponent(0.8))]
        )
        ring.position = [position.x, Self.tableTop + 0.004, position.z]
        root.addChild(ring)
        glowRings.append(ring)
    }

    private func clearGlow() {
        for ring in glowRings {
            ring.removeFromParent()
        }
        glowRings = []
    }

    // MARK: - UI

    private var controlPanel: some View {
        VStack(spacing: 20) {
            Text(panelPrompt)
                .font(.system(size: 32, weight: .semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 640)

            HStack(spacing: 16) {
                if exercise.phase == .won {
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
        }
        .padding(32)
        .glassBackgroundEffect()
    }

    private var panelPrompt: String {
        if let ceremonyPrompt {
            return ceremonyPrompt
        }
        switch exercise.phase {
        case .loading:
            return "Setting up the table…"
        case .playerDraw:
            return "Take any wall tile to your rack — \(exercise.meldsCompleted) of \(MahjongExercise.meldsToWin) sets."
        case .playerDiscard:
            return "Throw one of your tiles into the glowing circle."
        case .computerTurn:
            return "The computer is thinking…"
        case .won:
            return "Mahjong! You won. Fantastic!"
        }
    }
}
