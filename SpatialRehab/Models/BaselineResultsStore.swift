import Foundation

/// Local persistence for baseline assessment results.
///
/// A small `UserDefaults`-backed store rather than a real database — this branch has no
/// analytics backend to integrate with yet (`feature/analytics`'s dashboard/store isn't
/// merged into `main`). Kept intentionally simple so folding these results into that store
/// later is a data migration, not a rewrite.
enum BaselineResultsStore {
    private enum Key {
        static let wordMemoryResult = "baseline.wordMemoryResult"
        static let patternMatchingResult = "baseline.patternMatchingResult"
        static let arithmeticResult = "baseline.arithmeticResult"
        static let clockDrawingResult = "baseline.clockDrawingResult"
    }

    static func save(_ result: WordMemoryTrial) {
        save(result, forKey: Key.wordMemoryResult)
    }

    static func loadWordMemoryResult() -> WordMemoryTrial? {
        load(forKey: Key.wordMemoryResult)
    }

    static func save(_ result: PatternMatchingResult) {
        save(result, forKey: Key.patternMatchingResult)
    }

    static func loadPatternMatchingResult() -> PatternMatchingResult? {
        load(forKey: Key.patternMatchingResult)
    }

    static func save(_ result: ArithmeticResult) {
        save(result, forKey: Key.arithmeticResult)
    }

    static func loadArithmeticResult() -> ArithmeticResult? {
        load(forKey: Key.arithmeticResult)
    }

    static func save(_ result: ClockDrawingResult) {
        save(result, forKey: Key.clockDrawingResult)
    }

    static func loadClockDrawingResult() -> ClockDrawingResult? {
        load(forKey: Key.clockDrawingResult)
    }

    private static func save(_ value: some Encodable, forKey key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
