import RealityKit
import SwiftUI
import UIKit

/// Singapore Mahjong on a proper four-seat table, played by the real rules:
/// four sets plus an eye wins, flowers and animals expose with replacements,
/// and Pong / Chow / Mahjong! claims appear when an opponent's discard fits
/// the patient's hand. The deal is a genuine near-win and the wall and
/// opponents are quietly kind — the patient always reaches a real Mahjong.
struct MahjongActivityView: View {
    struct TileManifest: Decodable {
        struct Tile: Decodable {
            let prim: String
            let face: String
        }
        let tiles: [Tile]
    }

    enum SeatID: Int, CaseIterable {
        case player, right, across, left

        var name: String {
            switch self {
            case .player: return "You"
            case .right: return "Ah Hua"
            case .across: return "Uncle Lim"
            case .left: return "Mei Mei"
            }
        }

        var out: SIMD3<Float> {
            switch self {
            case .player: return [0, 0, 1]
            case .right: return [1, 0, 0]
            case .across: return [0, 0, -1]
            case .left: return [-1, 0, 0]
            }
        }

        var side: SIMD3<Float> {
            switch self {
            case .player, .across: return [1, 0, 0]
            case .right, .left: return [0, 0, 1]
            }
        }

        var yaw: Float {
            switch self {
            case .player: return 0
            case .right: return .pi / 2
            case .across: return .pi
            case .left: return -.pi / 2
            }
        }
    }

    enum ClaimAction {
        case win, pong, chow, pass
    }

    static let tableTop: Float = 0.85
    static let center = SIMD3<Float>(0, tableTop, -0.97)
    static let tileHeight: Float = 0.034
    static let tileSpacing: Float = 0.028
    static let rowSpacing: Float = 0.037
    static let faceDown = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
    static let faceUp = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
    static let handPitch = simd_quatf(angle: -0.26, axis: [1, 0, 0])

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    @State private var root = Entity()
    @State private var tilesByPrim: [String: Entity] = [:]
    @State private var faceByPrim: [String: String] = [:]
    @State private var primByEntityID: [Entity.ID: String] = [:]
    @State private var tileThickness: Float = 0.02
    @State private var handPrims: [String] = []
    @State private var aiHands: [SeatID: [String]] = [:]
    @State private var wallResidents: Set<String> = []
    @State private var wallHome: [String: Transform] = [:]
    @State private var wallOrderList: [String] = []
    @State private var lockedPrims: Set<String> = []
    @State private var riverCounts: [SeatID: Int] = [:]
    @State private var bonusCounts: [SeatID: Int] = [:]
    @State private var drawGlowPrim: String?
    @State private var glowRings: [Entity] = []
    @State private var discardZoneGlow = Entity()
    @State private var handPad = Entity()
    @State private var subscriptions: [EventSubscription] = []
    @State private var isResolving = false
    @State private var ceremonyStarted = false
    @State private var playReady = false
    @State private var ceremonyPrompt: String?
    @State private var claimAction: ClaimAction?
    @State private var audio = MahjongAudio()
    @State private var handTracker = HandWashTracker()
    /// False once the immersive space is dismissed — gameplay tasks check it so
    /// a dead session can't keep speaking or mutating the shared engine.
    @State private var sessionActive = true
    /// The in-flight draw/discard/AI-round task, cancelled on teardown.
    @State private var turnTask: Task<Void, Never>?
    /// Hand-row slot x-positions already promised to tiles still gliding in,
    /// so two quick pad drops can't be assigned the same slot.
    @State private var handRowTargets: [String: Float] = [:]

    private var exercise: MahjongExercise { appModel.mahjong }

    var body: some View {
        RealityView { content, attachments in
            content.add(root)
            buildTable()
            buildDiscardZoneGlow()
            buildHandPad()
            if let panel = attachments.entity(for: "mahjongPanel") {
                panel.position = [0, 1.52, -1.75]
                content.add(panel)
            }
            if let padTag = attachments.entity(for: "handPadTag") {
                padTag.position = handPadCenter + [0, 0.07, 0]
                content.add(padTag)
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
            Attachment(id: "handPadTag") {
                Text("Put tiles here")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.35)))
                    .foregroundStyle(.white)
            }
        }
        .task {
            guard !ceremonyStarted else { return }
            ceremonyStarted = true
            await openingCeremony()
        }
        .onDisappear {
            sessionActive = false
            turnTask?.cancel()
            audio.stopWash()
            audio.shutdown()
            handTracker.stop()
            appModel.voice.stop()
            if appModel.phase == .inActivity {
                appModel.phase = .welcome
            }
        }
    }

    private func pause(_ milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return true
        } catch {
            return false
        }
    }

    // MARK: - Geometry

    private func linePosition(_ seat: SeatID, radius: Float, offset: Float, y: Float = 0.001) -> SIMD3<Float> {
        Self.center + seat.out * radius + seat.side * offset + [0, y, 0]
    }

    private func standingRotation(_ seat: SeatID) -> simd_quatf {
        simd_quatf(angle: seat.yaw, axis: [0, 1, 0])
    }

    private func flatRotation(_ seat: SeatID, faceUp: Bool) -> simd_quatf {
        simd_quatf(angle: seat.yaw, axis: [0, 1, 0]) * (faceUp ? Self.faceUp : Self.faceDown)
    }

    private func riverSlot(_ seat: SeatID) -> SIMD3<Float> {
        let count = riverCounts[seat, default: 0]
        riverCounts[seat] = count + 1
        let column = count % 6
        let row = min(count / 6, 2)
        return linePosition(
            seat,
            radius: 0.17 - Float(row) * Self.rowSpacing,
            offset: (Float(column) - 2.5) * Self.tileSpacing,
            y: 0.002
        )
    }

    private func bonusSlot(_ seat: SeatID) -> SIMD3<Float> {
        let count = bonusCounts[seat, default: 0]
        bonusCounts[seat] = count + 1
        return linePosition(
            seat,
            radius: 0.30,
            offset: -0.34 - Float(count) * (Self.tileSpacing + 0.002),
            y: 0.002
        )
    }

    private func meldSlot(index: Int, offsetInMeld: Int) -> SIMD3<Float> {
        linePosition(
            .player,
            radius: 0.30,
            offset: 0.30 + Float(index) * 0.1 + Float(offsetInMeld) * (Self.tileSpacing + 0.002),
            y: 0.002
        )
    }

    private func handSlot(_ seat: SeatID, index: Int) -> SIMD3<Float> {
        linePosition(seat, radius: 0.37, offset: (Float(index) - 6.5) * Self.tileSpacing)
    }

    private func faceOf(_ prim: String) -> String {
        faceByPrim[prim] ?? ""
    }

    // MARK: - Table dressing

    private func buildTable() {
        let felt = SimpleMaterial(
            color: UIColor(red: 0.13, green: 0.35, blue: 0.25, alpha: 1),
            roughness: 0.9,
            isMetallic: false
        )
        let top = ModelEntity(
            mesh: .generateBox(size: [1.24, 0.05, 1.24], cornerRadius: 0.02),
            materials: [felt]
        )
        top.position = Self.center + [0, -0.028, 0]
        root.addChild(top)

        let rim = SimpleMaterial(
            color: UIColor(red: 0.45, green: 0.3, blue: 0.18, alpha: 1),
            roughness: 0.6,
            isMetallic: false
        )
        for seat in SeatID.allCases {
            let edge = ModelEntity(
                mesh: .generateBox(size: [1.3, 0.06, 0.04], cornerRadius: 0.01),
                materials: [rim]
            )
            edge.position = Self.center + seat.out * 0.63 + [0, 0.008, 0]
            edge.orientation = simd_quatf(angle: seat.yaw, axis: [0, 1, 0])
            root.addChild(edge)
        }

        let legMaterial = SimpleMaterial(
            color: UIColor(red: 0.42, green: 0.29, blue: 0.18, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )
        for x in [-0.55, 0.55] {
            for dz in [-0.55, 0.55] {
                let leg = ModelEntity(mesh: .generateBox(size: [0.06, 0.8, 0.06]), materials: [legMaterial])
                leg.position = [Self.center.x + Float(x), 0.4, Self.center.z + Float(dz)]
                root.addChild(leg)
            }
        }
    }

    private var handPadCenter: SIMD3<Float> {
        linePosition(.player, radius: 0.37, offset: 0.42, y: 0.0015)
    }

    /// Soft pad beside the hand row: anything dropped here joins the
    /// patient's tiles, neatly slotted into the line.
    private func buildHandPad() {
        var material = UnlitMaterial(color: UIColor(red: 0.4, green: 0.9, blue: 0.6, alpha: 1))
        material.blending = .transparent(opacity: 0.22)
        let pad = ModelEntity(
            mesh: .generateBox(size: [0.15, 0.003, 0.11], cornerRadius: 0.02),
            materials: [material]
        )
        handPad.addChild(pad)
        handPad.position = handPadCenter
        root.addChild(handPad)
    }

    /// Slot a tile into the first free position along the hand line.
    private func placeInHandRow(_ tile: Entity) {
        let movingPrim = primByEntityID[tile.id]
        let lineZ = Self.center.z + 0.37
        // Occupied = tiles already sitting in the row, plus slots promised to
        // tiles still gliding toward it — a second quick pad drop must not be
        // assigned the same slot as one still in flight.
        var occupied: [Float] = handPrims.compactMap { prim in
            guard prim != movingPrim, let other = tilesByPrim[prim] else { return nil }
            guard abs(other.position.z - lineZ) < 0.06 else { return nil }
            return other.position.x
        }
        occupied += handRowTargets.compactMap { $0.key == movingPrim ? nil : $0.value }
        var slotIndex = 0
        while slotIndex < 16 {
            let x = Self.center.x + (Float(slotIndex) - 6.5) * Self.tileSpacing
            if !occupied.contains(where: { abs($0 - x) < Self.tileSpacing * 0.6 }) {
                break
            }
            slotIndex += 1
        }
        let slot = handSlot(.player, index: slotIndex)
        if let movingPrim {
            handRowTargets[movingPrim] = slot.x
        }
        settleStanding(tile, at: slot, pitched: true)
    }

    private func buildDiscardZoneGlow() {
        var material = UnlitMaterial(color: UIColor.cyan.withAlphaComponent(0.3))
        material.blending = .transparent(opacity: 0.3)
        let pad = ModelEntity(
            mesh: .generateBox(size: [0.36, 0.003, 0.17], cornerRadius: 0.02),
            materials: [material]
        )
        discardZoneGlow.addChild(pad)
        discardZoneGlow.position = linePosition(.player, radius: 0.133, offset: 0, y: 0.0015)
        discardZoneGlow.isEnabled = false
        root.addChild(discardZoneGlow)
    }

    // MARK: - Opening ceremony

    private func openingCeremony() async {
        guard
            let manifestURL = Bundle.main.url(forResource: "mahjong_full_set_sg148.tiles", withExtension: "json"),
            let data = try? Data(contentsOf: manifestURL),
            let manifest = try? JSONDecoder().decode(TileManifest.self, from: data),
            let fullSet = try? await Entity(named: "mahjong_full_set_sg148")
        else { return }

        var random = NeighborhoodWorld.SeededRandom(state: UInt64(Date.now.timeIntervalSince1970))

        var normalizeScale: Float?
        for tile in manifest.tiles {
            let name = String(tile.prim.split(separator: "/").last ?? "")
            guard let source = fullSet.findEntity(named: name) else { continue }
            let model = source.clone(recursive: true)
            if normalizeScale == nil {
                let bounds = model.visualBounds(relativeTo: model)
                normalizeScale = Self.tileHeight / max(bounds.extents.y, 0.001)
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

        // Destinies: a genuine near-win for the patient, thirteen each for
        // the opponents, everything else to the wall.
        var byFace: [String: [String]] = [:]
        for prim in tilesByPrim.keys {
            byFace[faceOf(prim), default: []].append(prim)
        }
        let hand = buildTenpaiHand(&byFace, random: &random)

        var pool = byFace.values.flatMap { $0 }.shuffled(using: &random)
        pool.removeAll { hand.contains($0) }
        for seat in [SeatID.right, .across, .left] {
            aiHands[seat] = Array(pool.prefix(13))
            pool.removeFirst(min(13, pool.count))
            // Opponents' concealed tiles are never the patient's to grab —
            // otherwise they could be picked up, read, and stranded in the
            // patient's own row where no rule can ever discard them.
            for prim in aiHands[seat] ?? [] {
                lockTile(prim)
            }
        }
        wallOrderList = pool
        wallResidents = Set(pool)

        var finals: [String: Transform] = [:]
        let perSide = (pool.count + 7) / 8
        var wallIndex = 0
        // Wall consumption order: top tile then bottom tile of each stack,
        // starting from the patient's right and marching around — so
        // wallOrderList doubles as the strict draw order.
        for seat in [SeatID.right, .across, .left, .player] {
            for column in 0..<perSide {
                for tier in 0..<2 {
                    guard wallIndex < pool.count else { break }
                    let prim = pool[wallIndex]
                    wallIndex += 1
                    let transform = Transform(
                        scale: tilesByPrim[prim]?.scale ?? .one,
                        rotation: flatRotation(seat, faceUp: false),
                        translation: linePosition(
                            seat,
                            radius: 0.24,
                            offset: (Float(column) - Float(perSide - 1) / 2) * Self.tileSpacing,
                            y: 0.001 + Float(1 - tier) * tileThickness
                        )
                    )
                    finals[prim] = transform
                    wallHome[prim] = transform
                }
            }
        }
        let sortedHand = hand.sorted { faceOf($0) < faceOf($1) }
        for (index, prim) in sortedHand.enumerated() {
            finals[prim] = Transform(
                scale: tilesByPrim[prim]?.scale ?? .one,
                rotation: Self.handPitch,
                translation: handSlot(.player, index: index)
            )
        }
        for seat in [SeatID.right, .across, .left] {
            for (index, prim) in (aiHands[seat] ?? []).enumerated() {
                finals[prim] = Transform(
                    scale: tilesByPrim[prim]?.scale ?? .one,
                    rotation: standingRotation(seat),
                    translation: handSlot(seat, index: index)
                )
            }
        }
        handPrims = sortedHand

        func finishInstantly() {
            // Cancellation from teardown must not speak or flip the shared
            // engine for a session that no longer exists.
            guard sessionActive else { return }
            for (prim, transform) in finals {
                tilesByPrim[prim]?.transform = transform
            }
            completeSetup(sortedHand: sortedHand, finals: finals)
        }

        // Wash carpet.
        let allPrims = Array(tilesByPrim.keys).shuffled(using: &random)
        let washCenter = SIMD2<Float>(Self.center.x, Self.center.z)
        var carpet: [String: SIMD2<Float>] = [:]
        for (index, prim) in allPrims.enumerated() {
            let base = washCenter + SIMD2(Float(index % 13 - 6) * 0.04, Float(index / 13 - 5) * 0.04)
            carpet[prim] = base
            tilesByPrim[prim]?.position = [base.x, Self.tableTop + 0.001, base.y]
            tilesByPrim[prim]?.orientation = Self.faceDown
        }

        ceremonyPrompt = "Wash the tiles with your hands…"
        appModel.voice.speak("First, we wash the tiles. Swish them around with your hands — just like at home.")
        audio.startWash()
        Task { await handTracker.start() }

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
                let offset = base - washCenter
                let home = SIMD2(
                    washCenter.x + offset.x * cosA - offset.y * sinA,
                    washCenter.y + offset.x * sinA + offset.y * cosA
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
                let fromCenter = position - washCenter
                let radius = simd_length(fromCenter)
                if radius > 0.3 {
                    position = washCenter + fromCenter / radius * 0.3
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

        ceremonyPrompt = "Building the walls…"
        appModel.voice.speak("Now we stack the walls.")
        for (index, prim) in pool.enumerated() {
            guard let tile = tilesByPrim[prim], let transform = wallHome[prim] else { continue }
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

        ceremonyPrompt = "Dealing…"
        appModel.voice.speak("And now we deal — thirteen tiles each.")
        for seat in [SeatID.right, .across, .left] {
            for prim in aiHands[seat] ?? [] {
                guard let tile = tilesByPrim[prim], let transform = finals[prim] else { continue }
                tile.move(to: transform, relativeTo: root, duration: 0.35, timingFunction: .easeInOut)
                guard await pause(25) else {
                    finishInstantly()
                    return
                }
            }
        }
        for prim in sortedHand {
            guard let tile = tilesByPrim[prim], let transform = finals[prim] else { continue }
            tile.move(to: transform, relativeTo: root, duration: 0.4, timingFunction: .easeInOut)
            audio.click()
            guard await pause(55) else {
                finishInstantly()
                return
            }
        }
        _ = await pause(500)

        // Opponents expose any flowers/animals they were dealt, with
        // replacements from the far wall — proper Singapore procedure.
        let bonusCorrections = await exposeAIBonusTiles()
        finals.merge(bonusCorrections) { _, new in new }

        completeSetup(sortedHand: sortedHand, finals: finals)
    }

    private func completeSetup(sortedHand: [String], finals: [String: Transform]) {
        // Tidy pass: anything disturbed mid-ceremony (a grab during the wash
        // or deal) glides back to its rightful spot before play begins.
        for (prim, transform) in finals {
            guard let tile = tilesByPrim[prim],
                  simd_distance(tile.position, transform.translation) > 0.005
            else { continue }
            tile.move(to: transform, relativeTo: root, duration: 0.4, timingFunction: .easeInOut)
        }
        ceremonyPrompt = nil
        exercise.dealt(sortedHand.map(faceOf))
        playReady = true
        appModel.voice.speak(
            "Four sets and a pair wins. A set is three of the same tile, or three numbers in a row of one suit. Take the shining tile from the wall and drop it on the little green pad beside your tiles."
        )
        beginPlayerDraw()
    }

    /// Three complete sets + eye + one waiting pair — a genuine tenpai deal.
    private func buildTenpaiHand(
        _ byFace: inout [String: [String]],
        random: inout NeighborhoodWorld.SeededRandom
    ) -> [String] {
        for _ in 0..<8 {
            var local = byFace
            var prims: [String] = []
            var faces: [String] = []
            func take(_ face: String, _ count: Int) -> Bool {
                guard (local[face]?.count ?? 0) >= count else { return false }
                for _ in 0..<count {
                    prims.append(local[face]!.removeFirst())
                    faces.append(face)
                }
                return true
            }
            let suits = MahjongRules.Suit.allCases.shuffled(using: &random)
            var ok = true
            for chowIndex in 0..<2 {
                let suit = suits[chowIndex % suits.count]
                let start = Int.random(in: 1...7, using: &random)
                if !(take(MahjongRules.faceName(suit, start), 1)
                    && take(MahjongRules.faceName(suit, start + 1), 1)
                    && take(MahjongRules.faceName(suit, start + 2), 1)) {
                    ok = false
                    break
                }
            }
            guard ok else { continue }
            guard let pongFace = local.keys
                .filter({ !MahjongRules.isBonus($0) && local[$0]!.count >= 3 })
                .shuffled(using: &random).first,
                take(pongFace, 3)
            else { continue }
            guard let eyeFace = local.keys
                .filter({ !MahjongRules.isBonus($0) && $0 != pongFace && local[$0]!.count >= 2 })
                .shuffled(using: &random).first,
                take(eyeFace, 2)
            else { continue }
            let suit = suits[2 % suits.count]
            let start = Int.random(in: 2...7, using: &random)
            guard take(MahjongRules.faceName(suit, start), 1),
                  take(MahjongRules.faceName(suit, start + 1), 1)
            else { continue }
            guard prims.count == 13,
                  !MahjongRules.winningFaces(concealed: faces, exposedSets: 0).isEmpty
            else { continue }
            byFace = local
            return prims
        }
        // Fallback: any thirteen playable tiles.
        var prims: [String] = []
        for (face, facePrims) in byFace where !MahjongRules.isBonus(face) {
            for prim in facePrims where prims.count < 13 {
                prims.append(prim)
            }
        }
        for prim in prims {
            byFace[faceOf(prim)]?.removeAll { $0 == prim }
        }
        return prims
    }

    /// Returns the corrected final transforms for every tile it moved, so the
    /// ceremony's tidy pass doesn't drag exposed flowers back into hands.
    private func exposeAIBonusTiles() async -> [String: Transform] {
        var corrections: [String: Transform] = [:]
        for seat in [SeatID.right, .across, .left] {
            var hand = aiHands[seat] ?? []
            while let bonusIndex = hand.firstIndex(where: { MahjongRules.isBonus(faceOf($0)) }) {
                let prim = hand.remove(at: bonusIndex)
                if let tile = tilesByPrim[prim] {
                    lockTile(prim)
                    let transform = Transform(
                        scale: tile.scale,
                        rotation: flatRotation(seat, faceUp: true),
                        translation: bonusSlot(seat)
                    )
                    corrections[prim] = transform
                    tile.move(to: transform, relativeTo: root, duration: 0.45, timingFunction: .easeInOut)
                    audio.click()
                }
                if let replacement = replacementWallPrim() {
                    consumeWallPrim(replacement)
                    hand.append(replacement)
                    if let tile = tilesByPrim[replacement] {
                        lockTile(replacement)
                        let transform = Transform(
                            scale: tile.scale,
                            rotation: standingRotation(seat),
                            translation: handSlot(seat, index: hand.count - 1)
                        )
                        corrections[replacement] = transform
                        tile.move(to: transform, relativeTo: root, duration: 0.4, timingFunction: .easeInOut)
                    }
                }
                _ = await pause(250)
            }
            aiHands[seat] = hand
        }
        return corrections
    }

    // MARK: - Grab

    private func configureGrab(_ prim: String) {
        guard let tile = tilesByPrim[prim], !tile.components.has(ManipulationComponent.self) else { return }
        let bounds = tile.visualBounds(relativeTo: tile)
        let size = SIMD3(
            max(bounds.extents.x + 0.018, 0.04),
            max(bounds.extents.y + 0.018, 0.045),
            max(bounds.extents.z + 0.018, 0.035)
        )
        ManipulationComponent.configureEntity(
            tile,
            allowedInputTypes: .all,
            collisionShapes: [.generateBox(size: size).offsetBy(translation: bounds.center)]
        )
    }

    private func lockTile(_ prim: String) {
        lockedPrims.insert(prim)
        handRowTargets[prim] = nil
        guard let tile = tilesByPrim[prim] else { return }
        tile.components.remove(ManipulationComponent.self)
        tile.components.remove(InputTargetComponent.self)
    }

    // MARK: - Free-placement release logic

    private func tileReleased(_ entity: Entity) {
        guard let prim = primByEntityID[entity.id],
              !lockedPrims.contains(prim)
        else { return }

        let position = entity.position
        let local = position - Self.center
        // Anywhere central counts as throwing to the table — like real
        // mahjong, not a precision target. The glowing pad is a suggestion.
        let inDiscardArea = local.z > -0.42 && local.z < 0.27 && abs(local.x) < 0.5
        let inHandZone = local.z > 0.28 && abs(local.x) < 0.6
        let onHandPad = simd_length(SIMD2(
            position.x - handPadCenter.x,
            position.z - handPadCenter.z
        )) < 0.1

        // Mid-ceremony: nothing game-legal can happen yet, but a released
        // tile must never hang in the air. The end-of-ceremony tidy pass
        // re-seats anything this leaves imperfect.
        guard playReady else {
            if let home = wallHome[prim] {
                entity.move(to: home, relativeTo: root, duration: 0.4, timingFunction: .easeOut)
            } else {
                settleFaceDown(entity, at: position)
            }
            return
        }

        // Game actions only while nothing is resolving; the settle fallbacks
        // below always run, so a tile released mid-resolution still lands
        // tidily on the felt instead of hanging where the pinch let go.
        if !isResolving {
            if exercise.phase == .playerDraw, wallResidents.contains(prim), inHandZone || onHandPad {
                if onHandPad {
                    placeInHandRow(entity)
                } else {
                    settleStanding(entity, at: position, pitched: true)
                }
                resolveDraw(prim: prim)
                return
            }
            if exercise.phase == .playerDraw, wallResidents.contains(prim), inDiscardArea {
                // Draw-and-throw in one motion — real mahjong's most natural
                // move. The tile is drawn, and if ordinary, discarded at once.
                settleStanding(entity, at: position, pitched: false)
                resolveDraw(prim: prim, thrownToRiver: true)
                return
            }
            if handPrims.contains(prim), onHandPad {
                placeInHandRow(entity)
                return
            }
            if exercise.phase == .playerDiscard, handPrims.contains(prim), inDiscardArea {
                resolveDiscard(prim: prim, tile: entity)
                return
            }
            if exercise.phase == .playerDraw, handPrims.contains(prim), inDiscardArea {
                // Rules: draw first, then throw. Gentle correction, tile returns.
                appModel.voice.speak("First take the shining tile from the wall — then you can throw one.")
                exercise.recordWrongDrop()
                placeInHandRow(entity)
                return
            }
        }

        handRowTargets[prim] = nil
        if wallResidents.contains(prim), !inHandZone {
            if let home = wallHome[prim] {
                entity.move(to: home, relativeTo: root, duration: 0.4, timingFunction: .easeOut)
            } else {
                settleFaceDown(entity, at: position)
            }
        } else {
            settleStanding(entity, at: position, pitched: handPrims.contains(prim))
        }
    }

    private func clampedToFelt(_ position: SIMD3<Float>) -> SIMD3<Float> {
        [
            min(max(position.x, Self.center.x - 0.58), Self.center.x + 0.58),
            Self.tableTop + 0.001,
            min(max(position.z, Self.center.z - 0.58), Self.center.z + 0.58),
        ]
    }

    private func settleStanding(_ tile: Entity, at position: SIMD3<Float>, pitched: Bool) {
        let target = clampedToFelt(position)
        let duration = TimeInterval(min(0.3 + simd_length(tile.position - target) * 0.9, 0.85))
        tile.move(
            to: Transform(
                scale: tile.scale,
                rotation: pitched ? Self.handPitch : .init(),
                translation: target
            ),
            relativeTo: root, duration: duration, timingFunction: .easeOut
        )
        Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000) + 20))
            audio.clack(volume: 0.4)
        }
    }

    private func settleFaceDown(_ tile: Entity, at position: SIMD3<Float>) {
        tile.move(
            to: Transform(scale: tile.scale, rotation: Self.faceDown, translation: clampedToFelt(position)),
            relativeTo: root, duration: 0.3, timingFunction: .easeOut
        )
    }

    // MARK: - Player turn

    /// The next tile in the strict wall order (top then bottom of each
    /// stack, marching around from the patient's right).
    private func nextWallPrim() -> String? {
        wallOrderList.first { wallResidents.contains($0) }
    }

    /// Removes a drawn tile from every wall structure. `wallOrderList` must
    /// never keep prims that already left the wall — the flower-replacement
    /// path pops from its far end and would otherwise re-draw a tile that is
    /// sitting in someone's hand or river, double-counting its face.
    private func consumeWallPrim(_ prim: String) {
        wallResidents.remove(prim)
        wallHome[prim] = nil
        wallOrderList.removeAll { $0 == prim }
    }

    /// Flower/season/animal replacements come from the far end of the wall.
    private func replacementWallPrim() -> String? {
        while let last = wallOrderList.last {
            if wallResidents.contains(last) { return last }
            wallOrderList.removeLast()
        }
        return nil
    }

    /// The wall is empty: end warmly as a drawn game instead of leaving the
    /// patient in a draw phase with nothing to draw and no working button.
    private func endDrawnGame() {
        clearGlow()
        discardZoneGlow.isEnabled = false
        ceremonyPrompt = nil
        isResolving = false
        exercise.wallExhausted()
        appModel.voice.speak(
            "And that's the whole wall — a full game of mahjong, wonderfully played. Press Done when you're ready.",
            interrupting: true
        )
    }

    /// Kindness, hidden inside the real procedure: silently swap two
    /// face-down wall tiles so the next-in-order tile is a winning one.
    /// Both are face-down, so the swap is physically undetectable.
    private func riggedKindnessSwap() {
        guard exercise.playerTurns >= 2 else { return }
        let wins = exercise.winningFaces
        guard let next = nextWallPrim(), !wins.contains(faceOf(next)),
              let winner = wallOrderList.first(where: {
                  wallResidents.contains($0) && wins.contains(faceOf($0))
              }),
              winner != next,
              let a = tilesByPrim[next], let b = tilesByPrim[winner]
        else { return }

        let homeA = wallHome[next]
        let homeB = wallHome[winner]
        wallHome[next] = homeB
        wallHome[winner] = homeA
        if let homeB { a.transform = homeB }
        if let homeA { b.transform = homeA }
        if let indexA = wallOrderList.firstIndex(of: next),
           let indexB = wallOrderList.firstIndex(of: winner) {
            wallOrderList.swapAt(indexA, indexB)
        }
    }

    private func beginPlayerDraw() {
        clearGlow()
        discardZoneGlow.isEnabled = false
        guard nextWallPrim() != nil else {
            endDrawnGame()
            return
        }
        riggedKindnessSwap()
        // The glow teaches the real order: the next tile in the wall
        // sequence. (Any wall tile is still accepted — house rule.)
        drawGlowPrim = nextWallPrim()
        if let prim = drawGlowPrim, let tile = tilesByPrim[prim] {
            glow(at: tile.position, radius: 0.04)
        }
    }

    private func resolveDraw(prim: String, thrownToRiver: Bool = false) {
        isResolving = true
        clearGlow()
        consumeWallPrim(prim)

        turnTask = Task {
            await handleDrawnTile(prim: prim, thrownToRiver: thrownToRiver)
        }
    }

    /// `thrownToRiver` = the natural draw-and-throw motion: the wall tile was
    /// released straight into the discard area, so if it's an ordinary tile it
    /// is discarded in the same breath — exactly as real mahjong allows.
    private func handleDrawnTile(prim: String, thrownToRiver: Bool = false) async {
        let face = faceOf(prim)
        let result = exercise.drew(face)
        guard await pause(400), sessionActive else { return }
        audio.clack(volume: 0.6)

        switch result {
        case .win:
            handPrims.append(prim)
            await celebrateMahjong()

        case .bonus:
            appModel.voice.speak("A flower! It goes to the side, and you take another tile.")
            if let tile = tilesByPrim[prim] {
                lockTile(prim)
                tile.move(
                    to: Transform(
                        scale: tile.scale,
                        rotation: flatRotation(.player, faceUp: true),
                        translation: bonusSlot(.player)
                    ),
                    relativeTo: root, duration: 0.5, timingFunction: .easeInOut
                )
            }
            guard await pause(600), sessionActive else { return }
            // Replacement from the far end of the wall, flown in for them.
            if let replacement = replacementWallPrim() {
                consumeWallPrim(replacement)
                if let tile = tilesByPrim[replacement] {
                    tile.move(
                        to: Transform(
                            scale: tile.scale,
                            rotation: Self.handPitch,
                            translation: linePosition(.player, radius: 0.37, offset: 0.2)
                        ),
                        relativeTo: root, duration: 0.55, timingFunction: .easeInOut
                    )
                }
                guard await pause(600), sessionActive else { return }
                await handleDrawnTile(prim: replacement)
                return
            }
            // A flower off the very last wall tile with no replacement left —
            // the game ends here as a draw.
            endDrawnGame()

        case .normal:
            handPrims.append(prim)
            if thrownToRiver, let tile = tilesByPrim[prim] {
                appModel.voice.speak("Taken and thrown in one motion — just like a regular!")
                resolveDiscard(prim: prim, tile: tile)
                return
            }
            if exercise.pairFaces.contains(face) {
                appModel.voice.speak("Lovely — that matches tiles you already have. Now throw one you don't need into your glowing river.")
            } else {
                appModel.voice.speak("That one's yours now. Throw a tile you don't need into your glowing river.")
            }
            isResolving = false
            beginPlayerDiscardPhase()
        }
    }

    private func beginPlayerDiscardPhase() {
        guard exercise.phase == .playerDiscard else { return }
        isResolving = false
        discardZoneGlow.isEnabled = true
        if let suggestion = exercise.suggestedDiscard,
           let prim = handPrims.first(where: { faceOf($0) == suggestion }),
           let tile = tilesByPrim[prim] {
            glow(at: tile.position, radius: 0.028)
        }
    }

    private func resolveDiscard(prim: String, tile: Entity) {
        isResolving = true
        clearGlow()
        discardZoneGlow.isEnabled = false
        handPrims.removeAll { $0 == prim }
        handRowTargets[prim] = nil
        lockTile(prim)
        exercise.discarded(faceOf(prim))
        placeInRiver(tile, seat: .player)

        turnTask = Task {
            guard await pause(600), sessionActive else { return }
            await aiRound()
        }
    }

    private func placeInRiver(_ tile: Entity, seat: SeatID) {
        let slot = riverSlot(seat)
        tile.move(
            to: Transform(scale: tile.scale, rotation: flatRotation(seat, faceUp: true), translation: slot),
            relativeTo: root, duration: 0.5, timingFunction: .easeInOut
        )
        Task {
            _ = await pause(500)
            audio.clack(volume: 0.7)
        }
    }

    // MARK: - Opponents (with claim windows)

    private func aiRound() async {
        for seat in [SeatID.right, .across, .left] {
            guard sessionActive else { return }
            ceremonyPrompt = "\(seat.name) is thinking…"
            var random = SystemRandomNumberGenerator()

            // Draw the next tile in the strict shared wall order — the
            // opponents visibly model the real procedure. Flowers expose to
            // the side with far-wall replacements, same as the patient's.
            var drewIntoHand = false
            var fromFarEnd = false
            while !drewIntoHand {
                guard sessionActive else { return }
                guard let prim = fromFarEnd ? replacementWallPrim() : nextWallPrim() else {
                    endDrawnGame()
                    return
                }
                consumeWallPrim(prim)
                lockTile(prim)
                guard let tile = tilesByPrim[prim] else { continue }
                if MahjongRules.isBonus(faceOf(prim)) {
                    tile.move(
                        to: Transform(
                            scale: tile.scale,
                            rotation: flatRotation(seat, faceUp: true),
                            translation: bonusSlot(seat)
                        ),
                        relativeTo: root, duration: 0.45, timingFunction: .easeInOut
                    )
                    audio.click()
                    _ = await pause(400)
                    fromFarEnd = true
                    continue
                }
                aiHands[seat, default: []].append(prim)
                tile.move(
                    to: Transform(
                        scale: tile.scale,
                        rotation: standingRotation(seat),
                        translation: handSlot(seat, index: 13)
                    ),
                    relativeTo: root, duration: 0.45, timingFunction: .easeInOut
                )
                _ = await pause(500)
                audio.click()
                drewIntoHand = true
            }

            _ = await pause(Int.random(in: 400...900, using: &random))

            // Choose a discard — quietly kind to the patient.
            guard var hand = aiHands[seat], !hand.isEmpty else { continue }
            let wins = exercise.winningFaces
            let pongable = exercise.pairFaces
            var discardIndex = Int.random(in: 0..<hand.count, using: &random)
            if exercise.playerTurns >= 3, seat == .left,
               Float.random(in: 0...1, using: &random) < 0.35,
               let winIndex = hand.firstIndex(where: { wins.contains(faceOf($0)) }) {
                discardIndex = winIndex
            } else if Float.random(in: 0...1, using: &random) < 0.4,
                      let pongIndex = hand.firstIndex(where: { pongable.contains(faceOf($0)) }) {
                discardIndex = pongIndex
            }
            let prim = hand.remove(at: discardIndex)
            aiHands[seat] = hand

            guard let tile = tilesByPrim[prim] else { continue }
            let hover = tile.position + [0, 0.005, 0]
            tile.move(
                to: Transform(scale: tile.scale, rotation: tile.orientation, translation: hover),
                relativeTo: root, duration: 0.2, timingFunction: .easeInOut
            )
            _ = await pause(Int.random(in: 300...600, using: &random))
            placeInRiver(tile, seat: seat)
            _ = await pause(550)

            for (index, handPrim) in (aiHands[seat] ?? []).enumerated() {
                tilesByPrim[handPrim]?.move(
                    to: Transform(
                        scale: tilesByPrim[handPrim]?.scale ?? .one,
                        rotation: standingRotation(seat),
                        translation: handSlot(seat, index: index)
                    ),
                    relativeTo: root, duration: 0.3, timingFunction: .easeInOut
                )
            }

            // Claim window: Mahjong / Pong / Chow on this discard. The
            // discarded tile itself glows so the patient's eye finds it.
            if let claim = exercise.evaluateClaim(discard: faceOf(prim), fromLeftSeat: seat == .left) {
                if let discarded = tilesByPrim[prim] {
                    glow(at: discarded.position, radius: 0.035)
                }
                let outcome = await runClaimWindow(claim: claim, discardPrim: prim)
                clearGlow()
                if outcome {
                    ceremonyPrompt = nil
                    return
                }
            }
            _ = await pause(250)
        }
        guard sessionActive else { return }
        ceremonyPrompt = nil
        exercise.computerFinished()
        // The turn is the patient's again — unblock their tile releases.
        // (Missing reset here left isResolving true after every AI round,
        // which froze all draws and discards from turn two onward.)
        isResolving = false
        appModel.voice.speak("Your turn. Take a tile from the wall — the shining one is lucky.")
        beginPlayerDraw()
    }

    /// Shows the claim buttons and resolves the choice; returns true when
    /// the round should stop (claim taken or game won).
    private func runClaimWindow(claim: MahjongExercise.Claim, discardPrim: String) async -> Bool {
        claimAction = nil
        ceremonyPrompt = nil
        if claim.canWin {
            appModel.voice.speak("Wait — that tile finishes your hand! Press Mahjong!", interrupting: true)
        } else if claim.canPong {
            appModel.voice.speak("You have two of those. You can say Pong to take it!")
        } else {
            appModel.voice.speak("That tile fits a run in your hand. You can say Chow to take it!")
        }

        var waited = 0
        while claimAction == nil, waited < 120 {
            _ = await pause(100)
            waited += 1
        }
        let action = claimAction ?? .pass
        claimAction = nil
        // Teardown mid-window: don't pass/claim into an engine whose session
        // is already gone.
        guard sessionActive else { return false }

        switch action {
        case .win where claim.canWin:
            exercise.claimWin()
            handPrims.append(discardPrim)
            await celebrateMahjong()
            return true

        case .pong where claim.canPong:
            if let used = exercise.claimPong() {
                await animateClaimMeld(discardPrim: discardPrim, usedFaces: used)
                appModel.voice.speak("Pong! Now throw a tile you don't need into your glowing river.")
                beginPlayerDiscardPhase()
                return true
            }
        case .chow where !claim.chowOptions.isEmpty:
            if let used = exercise.claimChow(option: claim.chowOptions[0]) {
                await animateClaimMeld(discardPrim: discardPrim, usedFaces: used)
                appModel.voice.speak("Chow! Now throw a tile you don't need into your glowing river.")
                beginPlayerDiscardPhase()
                return true
            }
        default:
            break
        }
        exercise.passClaim()
        return false
    }

    private func animateClaimMeld(discardPrim: String, usedFaces: [String]) async {
        audio.chime()
        var meldPrims: [String] = [discardPrim]
        for face in usedFaces {
            if let prim = handPrims.first(where: { faceOf($0) == face }) {
                handPrims.removeAll { $0 == prim }
                meldPrims.append(prim)
            }
        }
        let meldIndex = exercise.exposedSetCount - 1
        for (offset, prim) in meldPrims.enumerated() {
            lockTile(prim)
            guard let tile = tilesByPrim[prim] else { continue }
            tile.move(
                to: Transform(
                    scale: tile.scale,
                    rotation: flatRotation(.player, faceUp: true),
                    translation: meldSlot(index: meldIndex, offsetInMeld: offset)
                ),
                relativeTo: root, duration: 0.55, timingFunction: .easeInOut
            )
        }
        _ = await pause(650)
    }

    /// The reveal: the whole hand flips face-up in a line, chimes, and the
    /// voice announces a genuine Mahjong.
    private func celebrateMahjong() async {
        isResolving = true
        clearGlow()
        discardZoneGlow.isEnabled = false
        appModel.voice.speak("Mahjong! Four sets and a pair — you've won!", interrupting: true)
        for (index, prim) in handPrims.enumerated() {
            guard let tile = tilesByPrim[prim] else { continue }
            lockTile(prim)
            tile.move(
                to: Transform(
                    scale: tile.scale,
                    rotation: flatRotation(.player, faceUp: true),
                    translation: linePosition(
                        .player,
                        radius: 0.26,
                        offset: (Float(index) - Float(handPrims.count - 1) / 2) * (Self.tileSpacing + 0.002),
                        y: 0.003
                    )
                ),
                relativeTo: root, duration: 0.6, timingFunction: .easeInOut
            )
            audio.clack(volume: 0.5)
            _ = await pause(70)
        }
        audio.chime()
        isResolving = false
    }

    // MARK: - Glow

    private func glow(at position: SIMD3<Float>, radius: Float) {
        let ring = ModelEntity(
            mesh: .generateCylinder(height: 0.005, radius: radius + 0.018),
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
                .frame(maxWidth: 660)

            if exercise.phase == .claimWindow, let claim = exercise.pendingClaim {
                HStack(spacing: 16) {
                    if claim.canWin {
                        Button("Mahjong!") { claimAction = .win }
                            .font(.title2.weight(.bold))
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .tint(.orange)
                            .controlSize(.extraLarge)
                    }
                    if claim.canPong {
                        Button("Pong!") { claimAction = .pong }
                            .font(.title3)
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                    }
                    if !claim.chowOptions.isEmpty {
                        Button("Chow!") { claimAction = .chow }
                            .font(.title3)
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.capsule)
                            .controlSize(.large)
                    }
                    Button("No, thanks") { claimAction = .pass }
                        .font(.title3)
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                }
            }

            HStack(spacing: 16) {
                if exercise.phase == .won || exercise.phase == .drawn {
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
            return "Take a tile from the wall. Four sets and a pair wins."
        case .playerDiscard:
            return "Throw one of your tiles into your glowing river."
        case .claimWindow:
            return "That tile could be yours…"
        case .computerTurn:
            return "The table is playing…"
        case .won:
            return "Mahjong! You won. Fantastic!"
        case .drawn:
            return "The wall is finished — a good long game. Press Done."
        }
    }
}
