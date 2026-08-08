import Foundation

/// Per-game progress for the Daily Practice hub: a visible level (always climbs, never
/// scored), a difficulty level (1–30, gradually rises and adapts from performance — shown as
/// the tile's dot row, but never spoken of to the patient as "difficulty"), and the set of
/// days that game has been completed at least once (for streaks/the calendar view).
///
/// See `Docs/DailyPractice_Design.md` for why the visible level and difficulty level are
/// deliberately separate numbers.
struct GameProgress: Codable, Equatable {
    var visibleLevel: Int = 1
    var difficultyLevel: Int = PracticeDifficulty.levelRange.lowerBound
    var practicedDayStrings: Set<String> = []

    /// Draw & Trace only: which `DrawingSubject.id`s have been drawn at least once, ever.
    /// Draw & Trace has no `difficultyLevel` (see `PracticeGameKind.isDifficultyAdaptive`),
    /// so this is what its hub tile's dot grid shows instead — a permanent "collected" mark
    /// per subject rather than a difficulty meter. Unused (stays empty) for the other three
    /// games.
    var visitedDrawingSubjectIDs: Set<String> = []
}

/// Local persistence for Daily Practice progress, one `GameProgress` per `PracticeGameKind`,
/// plus streak/calendar helpers shared across games.
///
/// `UserDefaults`-backed, matching `BaselineResultsStore`'s pattern — same reasoning: no
/// analytics backend to integrate with yet on this branch. Folding this into a real store
/// later is a data migration, not a rewrite.
enum PracticeProgressStore {
    private static func key(for kind: PracticeGameKind) -> String {
        "practice.progress.\(kind.rawValue)"
    }

    static func progress(for kind: PracticeGameKind) -> GameProgress {
        guard let data = UserDefaults.standard.data(forKey: key(for: kind)),
              let decoded = try? JSONDecoder().decode(GameProgress.self, from: data)
        else { return GameProgress() }
        return decoded
    }

    /// Levels between each guaranteed step up the difficulty schedule — see
    /// `recordCompletion(for:score:visitedDrawingSubjectID:)`. **Revised 2026-08-09 from 3
    /// to 1**: at 3, the schedule alone only moved the dot grid once every 3 completed
    /// rounds, which on a 30-dot grid read as "the dots aren't moving" during any normal
    /// testing/demo session (correct behavior, just imperceptibly paced). At 1, every
    /// completed round guarantees at least one step forward by default — performance can
    /// still pull further ahead (great score) or hold back a step (struggling), but the
    /// baseline case is now "always visibly advances," which is what actually reads as
    /// "progressively harder" round to round. Reaches the max level (30) around visible
    /// level 30 at the baseline pace now, not ~88. Placeholder pace, not clinically tuned —
    /// see `Docs/DailyPractice_Design.md`.
    private static let levelsPerScheduledDifficultyIncrease = 1

    /// Call once when a round finishes. Bumps `visibleLevel` unconditionally, adapts
    /// `difficultyLevel` from `score` (ignored for non-adaptive games, e.g. Draw & Trace —
    /// pass `nil`), marks today as practiced, and — for Draw & Trace only — records
    /// `visitedDrawingSubjectID` as collected. Returns the updated progress so the caller (a
    /// completion screen) can show the new level immediately.
    ///
    /// Difficulty has two components: a **gradual schedule** tied to `visibleLevel` (so it
    /// never sits flat forever regardless of how many rounds have been played), plus a
    /// **performance nudge** layered on top (doing great pulls ahead of schedule; struggling
    /// eases back a step). See `Docs/DailyPractice_Design.md`.
    @discardableResult
    static func recordCompletion(
        for kind: PracticeGameKind,
        score: Double?,
        visitedDrawingSubjectID: String? = nil
    ) -> GameProgress {
        var current = progress(for: kind)
        current.visibleLevel += 1

        if kind.isDifficultyAdaptive {
            let minLevel = PracticeDifficulty.levelRange.lowerBound
            let maxLevel = PracticeDifficulty.levelRange.upperBound
            let scheduledLevel = min(maxLevel, minLevel + (current.visibleLevel - 1) / levelsPerScheduledDifficultyIncrease)

            if let score, score >= 0.8 {
                current.difficultyLevel = min(maxLevel, max(current.difficultyLevel, scheduledLevel) + 1)
            } else if let score, score <= 0.4 {
                current.difficultyLevel = max(minLevel, current.difficultyLevel - 1)
            } else {
                // Steady performance (or no score) — keep at least pace with the schedule,
                // never regress below where the schedule already put them.
                current.difficultyLevel = max(current.difficultyLevel, scheduledLevel)
            }
        }

        if let visitedDrawingSubjectID {
            current.visitedDrawingSubjectIDs.insert(visitedDrawingSubjectID)
        }

        current.practicedDayStrings.insert(todayString())
        save(current, for: kind)
        return current
    }

    static func practicedToday(for kind: PracticeGameKind) -> Bool {
        progress(for: kind).practicedDayStrings.contains(todayString())
    }

    // MARK: - Streaks & calendar

    /// Union of every game's practiced days — "did anything happen this day," for the
    /// combined calendar view. Computed on the fly rather than double-written, so there's one
    /// source of truth per game and no risk of the union drifting out of sync.
    static func combinedPracticedDayStrings() -> Set<String> {
        PracticeGameKind.allCases.reduce(into: Set<String>()) { union, kind in
            union.formUnion(progress(for: kind).practicedDayStrings)
        }
    }

    /// Consecutive days practiced, ending today. If today hasn't been practiced yet, an
    /// in-progress streak still counts through yesterday — a streak shouldn't read as broken
    /// just because it's still early in the day.
    static func currentStreak(dayStrings: Set<String>) -> Int {
        let calendar = Calendar.current
        var cursor = Date.now
        if !dayStrings.contains(dayString(for: cursor)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while dayStrings.contains(dayString(for: cursor)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func currentStreak(for kind: PracticeGameKind) -> Int {
        currentStreak(dayStrings: progress(for: kind).practicedDayStrings)
    }

    static func currentCombinedStreak() -> Int {
        currentStreak(dayStrings: combinedPracticedDayStrings())
    }

    private static let longestCombinedStreakKey = "practice.longestCombinedStreak"

    /// Badges are permanent achievements (Duolingo-style) — once earned, they stay earned
    /// even after a missed day resets the *current* streak back to 0. Call this whenever the
    /// calendar view appears to opportunistically record a new high-water mark; read
    /// `longestCombinedStreak()` for badge-earned checks, and `currentCombinedStreak()`
    /// separately for the live flame counter.
    @discardableResult
    static func recordCombinedStreakCheckpoint() -> Int {
        let current = currentCombinedStreak()
        let stored = longestCombinedStreak()
        guard current > stored else { return stored }
        UserDefaults.standard.set(current, forKey: longestCombinedStreakKey)
        return current
    }

    static func longestCombinedStreak() -> Int {
        UserDefaults.standard.integer(forKey: longestCombinedStreakKey)
    }

    private static func save(_ progress: GameProgress, for kind: PracticeGameKind) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        UserDefaults.standard.set(data, forKey: key(for: kind))
    }

    private static func todayString() -> String { dayString(for: .now) }

    static func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
