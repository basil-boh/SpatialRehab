import Foundation

/// Result of a single memory-flip pattern-matching trial (find all matching pairs of cards).
///
/// Scored by efficiency (pairs found relative to attempts made) rather than right/wrong,
/// since every mismatch is just a retry, not a failure — consistent with errorless-learning
/// intent elsewhere in this battery. See `Docs/BaselineAssessment_Design.md`.
struct PatternMatchingResult: Codable, Hashable {
    let pairCount: Int
    let moveCount: Int
    let completedAt: Date

    /// 1.0 for a perfect run (moves == pairs), lower as more attempts were needed.
    var score: Double {
        guard pairCount > 0 else { return 0 }
        return Double(pairCount) / Double(max(moveCount, pairCount))
    }
}
