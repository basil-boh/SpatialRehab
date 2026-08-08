import Foundation

/// Result of a single clock-drawing baseline trial.
///
/// Deliberately unscored: automated clock-drawing scoring (numeral placement, hand
/// proportions, etc.) is a real clinical-scoring problem, not something to fake with a
/// heuristic. Only the rasterized sketch is kept; a caregiver fills in `score` later
/// (planned for the caregiver dashboard on `feature/analytics`, not yet merged here). See
/// `Docs/BaselineAssessment_Design.md`.
struct ClockDrawingResult: Codable, Hashable {
    /// Filename only, not a full path — sandbox container paths aren't stable across
    /// reinstalls. Resolve to a full URL via `URL.documentsDirectory.appending(path:)`.
    let imageFileName: String

    let capturedAt: Date

    /// `nil` until a caregiver reviews the sketch. `Int?` is a placeholder for a clinical
    /// clock-scoring scale (e.g. Shulman 0–10); the exact scale is a clinical-content
    /// decision, not made here.
    var score: Int?
}
