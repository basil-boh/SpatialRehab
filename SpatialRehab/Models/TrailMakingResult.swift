import Foundation

/// Result of a single Trail Making-style trial: tap 8 numbered dots in ascending order.
///
/// Scored by efficiency (dots / attempts), same shape as `PatternMatchingResult` — an
/// out-of-order tap doesn't advance progress or show a "wrong" indicator, it's just
/// counted silently, consistent with the no-punishment principle used throughout this
/// battery. `durationSeconds` is captured for a caregiver's interest but isn't part of the
/// score — this battery deliberately never puts the patient under visible time pressure.
struct TrailMakingResult: Codable, Hashable {
    let dotCount: Int
    let errorCount: Int
    let durationSeconds: TimeInterval
    let completedAt: Date

    var score: Double {
        guard dotCount > 0 else { return 0 }
        return Double(dotCount) / Double(dotCount + errorCount)
    }
}
