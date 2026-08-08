import CoreGraphics
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

    enum DigitSpan {
        /// A single fixed-length trial, not an adaptive up/down staircase — matches the
        /// complexity level of the rest of this battery. A first pass, not clinically
        /// calibrated (a real digit-span test would start shorter and grow).
        static let sequence = [3, 8, 1, 6]
        static let revealSecondsPerDigit: TimeInterval = 1.0
    }

    enum TrailMaking {
        /// Fractional (0...1) positions within the game's canvas, scaled to its actual
        /// size at render time — deliberately scattered (not gridded) so the task still
        /// exercises visual search, matching the real Trail Making Test's presentation.
        static let dotPositions: [CGPoint] = [
            CGPoint(x: 0.15, y: 0.18),
            CGPoint(x: 0.55, y: 0.10),
            CGPoint(x: 0.85, y: 0.28),
            CGPoint(x: 0.30, y: 0.45),
            CGPoint(x: 0.70, y: 0.50),
            CGPoint(x: 0.15, y: 0.75),
            CGPoint(x: 0.50, y: 0.85),
            CGPoint(x: 0.85, y: 0.68),
        ]
    }

    enum Orientation {
        struct Question {
            let promptText: String
            let correctAnswer: String
            /// Includes `correctAnswer`; shuffled at render time by the view.
            let choices: [String]
        }

        /// Computed from the current date/time rather than static content — an
        /// orientation question with a hardcoded answer would be meaningless. Limited to
        /// day-of-week, time-of-day, and month, deliberately excluding the classic MMSE
        /// "what season is it?" question: seasons are hemisphere-dependent and don't map
        /// onto a tropical climate (this product's Singapore context per the product-vision
        /// doc's healthhub.sg citation)
        /// doc), so it would be actively wrong for this audience rather than just unscored.
        static func questions(now: Date = .now, calendar: Calendar = .current) -> [Question] {
            [
                dayOfWeekQuestion(now: now, calendar: calendar),
                timeOfDayQuestion(now: now, calendar: calendar),
                monthQuestion(now: now, calendar: calendar),
            ]
        }

        private static func dayOfWeekQuestion(now: Date, calendar: Calendar) -> Question {
            let allDays = calendar.weekdaySymbols
            let index = calendar.component(.weekday, from: now) - 1
            let correct = allDays[index]
            var distractors = allDays
            distractors.remove(at: index)
            let choices = ([correct] + Array(distractors.shuffled().prefix(3))).shuffled()
            return Question(promptText: "What day of the week is it?", correctAnswer: correct, choices: choices)
        }

        private static func timeOfDayQuestion(now: Date, calendar: Calendar) -> Question {
            let hour = calendar.component(.hour, from: now)
            let correct: String
            switch hour {
            case 5..<12: correct = "Morning"
            case 12..<17: correct = "Afternoon"
            case 17..<21: correct = "Evening"
            default: correct = "Night"
            }
            let choices = ["Morning", "Afternoon", "Evening", "Night"].shuffled()
            return Question(promptText: "What time of day is it?", correctAnswer: correct, choices: choices)
        }

        private static func monthQuestion(now: Date, calendar: Calendar) -> Question {
            let allMonths = calendar.monthSymbols
            let index = calendar.component(.month, from: now) - 1
            let correct = allMonths[index]
            var distractors = allMonths
            distractors.remove(at: index)
            let choices = ([correct] + Array(distractors.shuffled().prefix(3))).shuffled()
            return Question(promptText: "What month is it?", correctAnswer: correct, choices: choices)
        }
    }

    enum ReactionTime {
        static let trialCount = 3
        static let minDelaySeconds: TimeInterval = 1.0
        static let maxDelaySeconds: TimeInterval = 3.0
        static let shapeSymbolName = "circle.fill"
    }
}
