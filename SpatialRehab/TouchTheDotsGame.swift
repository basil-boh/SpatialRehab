import Foundation
import Observation
import simd

@Observable
@MainActor
final class TouchTheDotsGame {
    static let totalDots = 10

    private(set) var dotsPopped = 0
    private(set) var reactionTimes: [TimeInterval] = []
    private var currentDotShownAt: Date?
    private var lastPosition: SIMD3<Float>?

    var isFinished: Bool { dotsPopped >= Self.totalDots }

    var averageReactionTime: TimeInterval? {
        guard !reactionTimes.isEmpty else { return nil }
        return reactionTimes.reduce(0, +) / Double(reactionTimes.count)
    }

    func reset() {
        dotsPopped = 0
        reactionTimes = []
        currentDotShownAt = nil
        lastPosition = nil
    }

    func dotShown() {
        currentDotShownAt = Date.now
    }

    func dotPopped() {
        if let shownAt = currentDotShownAt {
            reactionTimes.append(Date.now.timeIntervalSince(shownAt))
            currentDotShownAt = nil
        }
        dotsPopped += 1
    }

    /// A reachable spot in front of the patient, kept at least 0.35 m from
    /// the previous dot so consecutive targets require a real movement.
    func nextDotPosition() -> SIMD3<Float> {
        var candidate = Self.randomPosition()
        if let last = lastPosition {
            for _ in 0..<8 where simd_distance(candidate, last) < 0.35 {
                candidate = Self.randomPosition()
            }
        }
        lastPosition = candidate
        return candidate
    }

    private static func randomPosition() -> SIMD3<Float> {
        SIMD3<Float>(
            Float.random(in: -0.55...0.55),
            Float.random(in: 1.05...1.65),
            Float.random(in: -1.35...(-1.0))
        )
    }
}
