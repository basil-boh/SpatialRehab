import Foundation

/// Result of the reaction-time/attention trial: a shape flashes at a random position after
/// a random delay (to prevent anticipation), the patient taps it, repeated a few times.
///
/// No `0...1` score — reaction time doesn't naturally normalize into a percentage the way
/// the other games' results do, so this reports the raw readings and lets a caregiver read
/// them directly, same spirit as `ClockDrawingResult` staying unscored rather than forcing
/// an arbitrary "good/bad" cutoff.
struct ReactionTimeResult: Codable, Hashable {
    let reactionTimesMs: [Double]
    let completedAt: Date

    var averageReactionTimeMs: Double {
        guard !reactionTimesMs.isEmpty else { return 0 }
        return reactionTimesMs.reduce(0, +) / Double(reactionTimesMs.count)
    }
}
