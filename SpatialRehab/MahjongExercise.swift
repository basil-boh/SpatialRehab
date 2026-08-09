import Foundation
import Observation

/// Simplified mahjong against the computer: draw from the wall, keep pairs,
/// lay down three-of-a-kind melds, discard to the middle. Two melds wins.
/// The wall is invisibly rigged in the patient's favor and every decision is
/// voice-guided — cultural authenticity with errorless pacing.
@Observable
@MainActor
final class MahjongExercise {
    enum Phase: Equatable {
        case loading
        case playerDraw
        case playerDiscard
        case computerTurn
        case won
    }

    static let meldsToWin = 2

    private(set) var phase: Phase = .loading
    private(set) var handFaces: [String] = []
    private(set) var meldsCompleted = 0
    private(set) var turns = 0
    private(set) var wrongDrops = 0
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?

    func begin() {
        phase = .loading
        handFaces = []
        meldsCompleted = 0
        turns = 0
        wrongDrops = 0
        startedAt = .now
        completedAt = nil
    }

    func dealt(_ faces: [String]) {
        handFaces = faces.sorted()
        phase = .playerDraw
    }

    /// Returns the meld face if this draw completed three of a kind.
    func drew(_ face: String) -> String? {
        turns += 1
        handFaces.append(face)
        handFaces.sort()
        let count = handFaces.filter { $0 == face }.count
        if count >= 3 {
            for _ in 0..<3 {
                if let index = handFaces.firstIndex(of: face) {
                    handFaces.remove(at: index)
                }
            }
            meldsCompleted += 1
            if meldsCompleted >= Self.meldsToWin {
                phase = .won
                completedAt = .now
            } else {
                phase = .playerDiscard
            }
            return face
        }
        phase = .playerDiscard
        return nil
    }

    func discarded(_ face: String) {
        if let index = handFaces.firstIndex(of: face) {
            handFaces.remove(at: index)
        }
        phase = .computerTurn
    }

    func computerFinished() {
        guard phase == .computerTurn else { return }
        phase = .playerDraw
    }

    func recordWrongDrop() {
        wrongDrops += 1
    }

    /// Faces the patient already holds two of — the wall rigging favors these.
    var pairFaces: [String] {
        var counts: [String: Int] = [:]
        for face in handFaces {
            counts[face, default: 0] += 1
        }
        return counts.filter { $0.value == 2 }.map(\.key)
    }

    /// A gentle discard suggestion: something they hold only one of.
    var suggestedDiscard: String? {
        var counts: [String: Int] = [:]
        for face in handFaces {
            counts[face, default: 0] += 1
        }
        return handFaces.first { counts[$0] == 1 } ?? handFaces.first
    }
}
