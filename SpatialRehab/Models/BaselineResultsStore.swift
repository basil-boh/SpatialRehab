import Foundation

/// Local persistence for baseline assessment results.
///
/// A small `UserDefaults`-backed store rather than a real database — this branch has no
/// analytics backend to integrate with yet (`feature/analytics`'s dashboard/store isn't
/// merged into `main`). Kept intentionally simple so folding these results into that store
/// later is a data migration, not a rewrite.
///
/// Each game's results are stored as an **appended history array**, not a single overwritten
/// value — fixed 2026-08-08 to actually support the battery's whole premise (a baseline you
/// compare later sessions against). `loadXResult()` accessors return the latest entry for
/// call sites that only ever wanted "what happened last time" (`BaselineResultsDebugView`,
/// `completedGameCount()`); `loadXHistory()` accessors return the full run for trend charts
/// (`CaregiverDashboardView`).
///
/// **One-way migration note:** results saved before this change were stored as a single
/// encoded value, not an array — decoding that old shape as `[T]` fails silently (returns an
/// empty array, per `loadArray`'s `try?`), so any pre-existing single-entry test data is
/// invisible after this change rather than crashing. Acceptable for a hackathon prototype
/// with only local test data; a real migration would need to attempt decoding both shapes.
enum BaselineResultsStore {
    private enum Key {
        static let reactionTimeResult = "baseline.reactionTimeResult"
        static let orientationResult = "baseline.orientationResult"
        static let wordMemoryResult = "baseline.wordMemoryResult"
        static let digitSpanResult = "baseline.digitSpanResult"
        static let patternMatchingResult = "baseline.patternMatchingResult"
        static let trailMakingResult = "baseline.trailMakingResult"
        static let arithmeticResult = "baseline.arithmeticResult"
        static let clockDrawingResult = "baseline.clockDrawingResult"
    }

    static func save(_ result: ReactionTimeResult) {
        append(result, forKey: Key.reactionTimeResult)
    }

    static func loadReactionTimeHistory() -> [ReactionTimeResult] {
        loadArray(forKey: Key.reactionTimeResult)
    }

    static func loadReactionTimeResult() -> ReactionTimeResult? {
        loadReactionTimeHistory().last
    }

    static func save(_ result: OrientationResult) {
        append(result, forKey: Key.orientationResult)
    }

    static func loadOrientationHistory() -> [OrientationResult] {
        loadArray(forKey: Key.orientationResult)
    }

    static func loadOrientationResult() -> OrientationResult? {
        loadOrientationHistory().last
    }

    static func save(_ result: WordMemoryTrial) {
        append(result, forKey: Key.wordMemoryResult)
    }

    static func loadWordMemoryHistory() -> [WordMemoryTrial] {
        loadArray(forKey: Key.wordMemoryResult)
    }

    static func loadWordMemoryResult() -> WordMemoryTrial? {
        loadWordMemoryHistory().last
    }

    static func save(_ result: DigitSpanResult) {
        append(result, forKey: Key.digitSpanResult)
    }

    static func loadDigitSpanHistory() -> [DigitSpanResult] {
        loadArray(forKey: Key.digitSpanResult)
    }

    static func loadDigitSpanResult() -> DigitSpanResult? {
        loadDigitSpanHistory().last
    }

    static func save(_ result: PatternMatchingResult) {
        append(result, forKey: Key.patternMatchingResult)
    }

    static func loadPatternMatchingHistory() -> [PatternMatchingResult] {
        loadArray(forKey: Key.patternMatchingResult)
    }

    static func loadPatternMatchingResult() -> PatternMatchingResult? {
        loadPatternMatchingHistory().last
    }

    static func save(_ result: TrailMakingResult) {
        append(result, forKey: Key.trailMakingResult)
    }

    static func loadTrailMakingHistory() -> [TrailMakingResult] {
        loadArray(forKey: Key.trailMakingResult)
    }

    static func loadTrailMakingResult() -> TrailMakingResult? {
        loadTrailMakingHistory().last
    }

    static func save(_ result: ArithmeticResult) {
        append(result, forKey: Key.arithmeticResult)
    }

    static func loadArithmeticHistory() -> [ArithmeticResult] {
        loadArray(forKey: Key.arithmeticResult)
    }

    static func loadArithmeticResult() -> ArithmeticResult? {
        loadArithmeticHistory().last
    }

    static func save(_ result: ClockDrawingResult) {
        append(result, forKey: Key.clockDrawingResult)
    }

    static func loadClockDrawingHistory() -> [ClockDrawingResult] {
        loadArray(forKey: Key.clockDrawingResult)
    }

    static func loadClockDrawingResult() -> ClockDrawingResult? {
        loadClockDrawingHistory().last
    }

    /// Number of the battery's games that have at least one saved result — used by
    /// `ContentView`'s "activities completed" stat.
    static func completedGameCount() -> Int {
        [
            loadReactionTimeResult() != nil,
            loadOrientationResult() != nil,
            loadWordMemoryResult() != nil,
            loadDigitSpanResult() != nil,
            loadPatternMatchingResult() != nil,
            loadTrailMakingResult() != nil,
            loadArithmeticResult() != nil,
            loadClockDrawingResult() != nil,
        ].filter { $0 }.count
    }

    private static func append<T: Codable>(_ value: T, forKey key: String) {
        var history: [T] = loadArray(forKey: key)
        history.append(value)
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadArray<T: Decodable>(forKey key: String) -> [T] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([T].self, from: data)) ?? []
    }
}
