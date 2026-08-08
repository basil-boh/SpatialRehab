import Foundation

/// One domain worth targeting in an upcoming session, ranked by how much it needs
/// attention, with the games that target it.
struct GameRecommendation: Hashable {
    let domain: CognitiveDomain

    /// `1 - score`, so a domain that scored lower ranks higher (more worth targeting).
    /// Not a diagnosis — just where this domain sits relative to the others measured.
    let priority: Double

    let games: [StimulationGame]
}

/// Ranks cognitive-stimulation games by which measured domain is currently weakest,
/// so a session can be biased toward it.
///
/// A plain weighted comparison, not a trained model, on purpose: a single patient
/// produces at most a handful of readings per domain, nowhere near enough to fit
/// anything meaningful, and a caregiver needs to be able to see *why* a domain was
/// picked. Clock-drawing/visuospatial is absent from the ranking, not zero-scored —
/// `CognitiveDomain` has no case for it while it stays unscored, so it simply never
/// appears rather than being (incorrectly) treated as the weakest domain by default.
enum GameRecommendationEngine {
    /// Ranks the given readings, most-worth-targeting first. Callers with real session
    /// data (not just baseline) can pass multiple readings per domain — only the most
    /// recent one per domain is used, so older readings don't drag a recovered domain
    /// back down.
    static func recommendations(from scores: [DomainScore]) -> [GameRecommendation] {
        latestReading(perDomainIn: scores)
            .map { domain, reading in
                GameRecommendation(
                    domain: domain,
                    priority: 1 - min(max(reading.value, 0), 1),
                    games: StimulationGameCatalog.games(for: domain)
                )
            }
            .sorted { $0.priority > $1.priority }
    }

    /// Convenience entry point reading current on-device baseline data directly.
    /// `recommendations(from:)` stays the one to call with synthetic data once this
    /// repo has a test target (see `Docs/BaselineAssessment_Design.md`'s known gaps).
    static func currentRecommendations() -> [GameRecommendation] {
        recommendations(from: BaselineResultsStore.currentDomainScores())
    }

    private static func latestReading(perDomainIn scores: [DomainScore]) -> [CognitiveDomain: DomainScore] {
        Dictionary(scores.map { ($0.domain, $0) }, uniquingKeysWith: { current, new in
            new.recordedAt > current.recordedAt ? new : current
        })
    }
}

extension BaselineResultsStore {
    /// Maps the most recently completed baseline trials to the domain scores
    /// `GameRecommendationEngine` ranks. Clock drawing is excluded — it has no `score`
    /// until a caregiver reviews it, so there is nothing to bridge yet.
    static func currentDomainScores() -> [DomainScore] {
        var scores: [DomainScore] = []
        if let result = loadWordMemoryResult() {
            scores.append(DomainScore(domain: .memory, value: result.score, recordedAt: result.completedAt))
        }
        if let result = loadArithmeticResult() {
            scores.append(DomainScore(domain: .numeracy, value: result.score, recordedAt: result.completedAt))
        }
        if let result = loadPatternMatchingResult() {
            scores.append(DomainScore(domain: .executiveFunction, value: result.score, recordedAt: result.completedAt))
        }
        return scores
    }
}
