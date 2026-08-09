import Foundation

/// Level-scaled content generators for the three difficulty-adaptive practice games (word
/// memory, pattern matching, arithmetic). Clock/Draw & Trace has no difficulty scale — see
/// `PracticeGameKind.isDifficultyAdaptive`.
///
/// Content is generated fresh each round (not a fixed table like `BaselineAssessmentContent`
/// uses) so a daily-repeated game doesn't get memorized rather than practiced. Placeholder
/// difficulty curves — not clinically reviewed. See `Docs/DailyPractice_Design.md`.
enum PracticeDifficulty {
    /// Valid difficulty-level range for every adaptive game. 1 = easiest, 30 = hardest —
    /// wide on purpose (was 1–5) so the gradual climb feels like real, sustained progress
    /// over weeks of daily play, not something maxed out in a handful of sessions.
    static let levelRange = 1...30

    enum WordMemory {
        /// Larger than the baseline's fixed 12-word list on purpose — practice rounds sample
        /// from this pool so the exact word set varies between sessions. Same "concrete,
        /// simple, high-imagery" style as the baseline list. Sized so the hardest tier's
        /// target+distractor count (9 + 9 = 18) still leaves margin below the pool size.
        static let wordBank = [
            "Apple", "River", "Chair", "Garden", "Pencil", "Cloud",
            "Table", "Ocean", "Window", "Ladder", "Basket", "Mountain",
            "Candle", "Kitten", "Bridge", "Blanket", "Hammer", "Turtle",
            "Umbrella", "Pillow", "Bicycle", "Lantern",
        ]

        /// 4 words at level 1, +1 every 5 levels, capped at 9 (leaves the word bank enough
        /// margin for an equal-sized distractor set).
        static func targetWordCount(forLevel level: Int) -> Int {
            min(9, 4 + (level - 1) / 5)
        }

        /// 15s to study at level 1, easing down to 5s by the highest levels.
        static func studyDurationSeconds(forLevel level: Int) -> TimeInterval {
            TimeInterval(max(5, 15 - (level - 1) / 2))
        }

        /// Draws a fresh target/distractor split from `wordBank` for one round at `level`.
        static func makeRound(level: Int) -> (targets: [String], distractors: [String]) {
            let count = targetWordCount(forLevel: level)
            let shuffled = wordBank.shuffled()
            let targets = Array(shuffled.prefix(count))
            let distractors = Array(shuffled.dropFirst(count).prefix(count))
            return (targets, distractors)
        }
    }

    enum PatternMatching {
        /// 12 symbols — enough for the hardest tier's 12 pairs. Simple, high-contrast,
        /// unambiguous SF Symbols, verified to exist in the installed SDK before use (see
        /// `Docs/DailyPractice_Design.md`) rather than assumed from memory.
        static let symbolPool = [
            "star.fill", "heart.fill", "leaf.fill", "sun.max.fill",
            "moon.stars.fill", "cloud.fill", "drop.fill", "flame.fill",
            "pawprint.fill", "gift.fill", "carrot.fill", "birthday.cake.fill",
        ]

        /// 3 pairs at level 1, +1 pair every 3 levels, capped at 12 (the symbol pool size).
        static func pairCount(forLevel level: Int) -> Int {
            min(symbolPool.count, 3 + (level - 1) / 3)
        }

        static func makeRoundSymbols(level: Int) -> [String] {
            Array(symbolPool.shuffled().prefix(pairCount(forLevel: level)))
        }
    }

    enum Arithmetic {
        /// 4 problems at level 1, +1 every 6 levels, capped at 8.
        static func problemCount(forLevel level: Int) -> Int {
            min(8, 4 + (level - 1) / 6)
        }

        /// Grows from 1–6 at level 1 up to 1–50 at the highest levels.
        static func numberRange(forLevel level: Int) -> ClosedRange<Int> {
            1...min(50, 4 + level * 2)
        }

        /// Subtraction introduced a little into the climb, not from level 1.
        static func allowsSubtraction(forLevel level: Int) -> Bool {
            level >= 6
        }

        static func makeProblems(level: Int) -> [BaselineAssessmentContent.Arithmetic.Problem] {
            let range = numberRange(forLevel: level)
            let allowSubtraction = allowsSubtraction(forLevel: level)
            return (0..<problemCount(forLevel: level)).map { _ in
                makeProblem(range: range, allowSubtraction: allowSubtraction)
            }
        }

        private static func makeProblem(
            range: ClosedRange<Int>,
            allowSubtraction: Bool
        ) -> BaselineAssessmentContent.Arithmetic.Problem {
            let useSubtraction = allowSubtraction && Bool.random()
            let a = Int.random(in: range)
            let b = Int.random(in: range)

            let promptText: String
            let answer: Int
            if useSubtraction {
                // Keep the result non-negative — larger minus smaller.
                let (large, small) = a >= b ? (a, b) : (b, a)
                promptText = "\(large) − \(small) = ?"
                answer = large - small
            } else {
                promptText = "\(a) + \(b) = ?"
                answer = a + b
            }

            var choices: Set<Int> = [answer]
            while choices.count < 4 {
                let offset = Int.random(in: -4...4)
                let candidate = answer + offset
                if candidate >= 0, candidate != answer {
                    choices.insert(candidate)
                }
            }

            return BaselineAssessmentContent.Arithmetic.Problem(
                promptText: promptText,
                correctAnswer: answer,
                choices: Array(choices).shuffled()
            )
        }
    }
}
