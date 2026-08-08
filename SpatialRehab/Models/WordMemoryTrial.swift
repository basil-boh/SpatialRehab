import Foundation

/// Result of a single word-memory recognition trial.
///
/// Recognition format (study a short list, then tap the words you remember from a
/// target+distractor grid), not free recall — chosen for baseline assessment because it
/// needs no typing/speech input, matching the low-friction interaction style used elsewhere
/// (`Done`/`Back`/`Skip` in `GuidanceCardView`). See `Docs/BaselineAssessment_Design.md`.
struct WordMemoryTrial: Codable, Hashable {
    let targetWords: [String]
    let distractorWords: [String]

    /// Every word the patient tapped during recall, regardless of whether it was a target.
    let tappedWords: Set<String>

    let completedAt: Date

    /// Computed rather than stored, so scoring logic can change later without re-running
    /// the trial.
    var correctlyRecognized: Set<String> {
        tappedWords.intersection(targetWords)
    }

    /// Tracked for the record (never surfaced as "wrong" in the UI — errorless learning).
    var falsePositives: Set<String> {
        tappedWords.subtracting(targetWords)
    }

    var score: Double {
        guard !targetWords.isEmpty else { return 0 }
        return Double(correctlyRecognized.count) / Double(targetWords.count)
    }
}
