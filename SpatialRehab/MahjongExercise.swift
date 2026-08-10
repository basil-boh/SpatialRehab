import Foundation
import Observation

/// Singapore Mahjong against the computer, played by the real rules —
/// four sets (chows/pongs) plus an eye wins; flowers, seasons, and animals
/// auto-expose with replacements; Pong/Chow/Mahjong claims on discards.
/// Errorless pacing: the deal is a genuine near-win, the wall is kind, and
/// the opponents feed claimable tiles. The patient always gets there.
@Observable
@MainActor
final class MahjongExercise {
    enum Phase: Equatable {
        case loading
        case playerDraw
        case playerDiscard
        case claimWindow
        case computerTurn
        case won
        /// The wall ran out — a drawn game, ended warmly rather than stranding
        /// the patient in a `playerDraw` with nothing left to draw.
        case drawn
    }

    enum DrawResult: Equatable {
        case win
        case bonus(String)
        case normal
    }

    struct Claim: Equatable {
        let discardFace: String
        let canWin: Bool
        let canPong: Bool
        let chowOptions: [[String]]
    }

    private(set) var phase: Phase = .loading
    private(set) var handFaces: [String] = []
    private(set) var exposedMelds: [[String]] = []
    private(set) var bonusFaces: [String] = []
    private(set) var pendingClaim: Claim?
    private(set) var playerTurns = 0
    private(set) var claimsMade = 0
    private(set) var wrongDrops = 0
    /// Visible, positive-only encouragement: points are only ever earned,
    /// never lost — no score anxiety for a dementia patient.
    private(set) var points = 0
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?

    var exposedSetCount: Int { exposedMelds.count }

    var winningFaces: Set<String> {
        MahjongRules.winningFaces(concealed: handFaces, exposedSets: exposedSetCount)
    }

    var suggestedDiscard: String? {
        MahjongRules.suggestedDiscard(from: handFaces)
    }

    var pairFaces: [String] {
        var counts: [String: Int] = [:]
        for face in handFaces {
            counts[face, default: 0] += 1
        }
        return counts.filter { $0.value >= 2 }.map(\.key)
    }

    func begin() {
        phase = .loading
        handFaces = []
        exposedMelds = []
        bonusFaces = []
        pendingClaim = nil
        playerTurns = 0
        claimsMade = 0
        wrongDrops = 0
        points = 0
        startedAt = .now
        completedAt = nil
    }

    func dealt(_ faces: [String]) {
        handFaces = faces.sorted()
        phase = .playerDraw
    }

    func exposeBonus(_ face: String) {
        bonusFaces.append(face)
        handFaces.removeAll { $0 == face }
    }

    func drew(_ face: String) -> DrawResult {
        if MahjongRules.isBonus(face) {
            bonusFaces.append(face)
            points += 2
            return .bonus(face)
        }
        // Counted only for real draws: flower-replacement chains must not
        // inflate the turn count and flip the pacing rig early.
        playerTurns += 1
        handFaces.append(face)
        handFaces.sort()
        if MahjongRules.isWinningHand(handFaces, exposedSets: exposedSetCount) {
            win()
            return .win
        }
        phase = .playerDiscard
        return .normal
    }

    func discarded(_ face: String) {
        if let index = handFaces.firstIndex(of: face) {
            handFaces.remove(at: index)
        }
        points += 1
        phase = .computerTurn
    }

    // MARK: - Claims on opponents' discards

    /// Evaluate what the patient may do with an opponent's discard.
    /// Chow is only legal from the player to their left.
    func evaluateClaim(discard: String, fromLeftSeat: Bool) -> Claim? {
        guard !MahjongRules.isBonus(discard) else { return nil }
        let canWin = MahjongRules.isWinningHand(
            handFaces + [discard], exposedSets: exposedSetCount
        )
        let canPong = handFaces.filter { $0 == discard }.count >= 2
        let chows = fromLeftSeat ? MahjongRules.chowOptions(for: discard, in: handFaces) : []
        guard canWin || canPong || !chows.isEmpty else { return nil }
        let claim = Claim(discardFace: discard, canWin: canWin, canPong: canPong, chowOptions: chows)
        pendingClaim = claim
        phase = .claimWindow
        return claim
    }

    func claimWin() {
        guard let claim = pendingClaim, claim.canWin else { return }
        handFaces.append(claim.discardFace)
        handFaces.sort()
        claimsMade += 1
        pendingClaim = nil
        win()
    }

    /// Returns the two hand faces consumed by the pong.
    func claimPong() -> [String]? {
        guard let claim = pendingClaim, claim.canPong else { return nil }
        var used: [String] = []
        for _ in 0..<2 {
            if let index = handFaces.firstIndex(of: claim.discardFace) {
                handFaces.remove(at: index)
                used.append(claim.discardFace)
            }
        }
        exposedMelds.append([claim.discardFace] + used)
        claimsMade += 1
        points += 5
        pendingClaim = nil
        phase = .playerDiscard
        return used
    }

    /// Returns the two hand faces consumed by the chow.
    func claimChow(option: [String]) -> [String]? {
        guard let claim = pendingClaim, claim.chowOptions.contains(option) else { return nil }
        for face in option {
            if let index = handFaces.firstIndex(of: face) {
                handFaces.remove(at: index)
            }
        }
        exposedMelds.append(([claim.discardFace] + option).sorted())
        claimsMade += 1
        points += 5
        pendingClaim = nil
        phase = .playerDiscard
        return option
    }

    func passClaim() {
        pendingClaim = nil
        phase = .computerTurn
    }

    func computerFinished() {
        guard phase == .computerTurn else { return }
        phase = .playerDraw
    }

    func recordWrongDrop() {
        wrongDrops += 1
    }

    /// The wall is empty: end as a drawn game (never from a won game).
    func wallExhausted() {
        guard phase != .won else { return }
        phase = .drawn
        completedAt = .now
    }

    private func win() {
        points += 25
        phase = .won
        completedAt = .now
    }
}
