import Foundation

/// Static content for the first-launch baseline assessment battery.
///
/// Word list, distractor set, and study duration are a first pass, not clinically
/// reviewed — same disclaimer `TeaTaskContent` uses for its task sequence. See
/// `Docs/BaselineAssessment_Design.md`.
enum BaselineAssessmentContent {
    enum WordMemory {
        static let targetWords = ["Apple", "River", "Chair", "Garden"]
        static let distractorWords = ["Table", "Ocean", "Window", "Ladder", "Basket", "Mountain"]
        static let studyDurationSeconds: TimeInterval = 10
    }

    enum ClockDrawing {
        static let promptText = "Draw a clock showing ten past eleven."
    }

    enum PatternMatching {
        /// SF Symbols used as card faces — six pairs (12 cards). Simple, high-contrast,
        /// unambiguous shapes rather than photorealistic icons.
        static let symbols = ["star.fill", "heart.fill", "leaf.fill", "sun.max.fill", "moon.stars.fill", "cloud.fill"]
    }

    enum Arithmetic {
        struct Problem {
            let promptText: String
            let correctAnswer: Int
            /// Includes `correctAnswer`; shuffled at render time by the view.
            let choices: [Int]
        }

        /// "Basic mental sums" per the product brief — single-digit addition only, a first
        /// pass not clinically reviewed, same disclaimer as the word list above.
        static let problems: [Problem] = [
            Problem(promptText: "3 + 4 = ?", correctAnswer: 7, choices: [5, 6, 7, 9]),
            Problem(promptText: "6 + 2 = ?", correctAnswer: 8, choices: [6, 7, 8, 10]),
            Problem(promptText: "5 + 5 = ?", correctAnswer: 10, choices: [8, 9, 10, 12]),
            Problem(promptText: "7 + 1 = ?", correctAnswer: 8, choices: [6, 8, 9, 11]),
        ]
    }
}
