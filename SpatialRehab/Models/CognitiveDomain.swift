import Foundation

/// A cognitive domain the baseline battery can produce an automatic score for.
///
/// Deliberately only the three domains the battery actually scores today
/// (see `Docs/BaselineAssessment_Design.md`'s battery table): word memory maps to
/// `.memory`, arithmetic to `.numeracy`, pattern matching to `.executiveFunction`.
/// Clock drawing measures a fourth domain, visuospatial ability, but is intentionally
/// left unscored (`ClockDrawingResult.score` stays `nil` until a caregiver reviews it),
/// so there is no automatic reading for it to join this enum yet — add a case here
/// once that scoring pipeline exists.
enum CognitiveDomain: String, CaseIterable, Codable, Hashable {
    case memory
    case numeracy
    case executiveFunction
}

/// One dated performance reading for a domain, in the `0...1` range (higher is better).
///
/// Shaped to match what a single baseline trial already produces (a score plus its
/// `completedAt` timestamp) rather than a running-total, so it works unchanged whether
/// it's fed one baseline snapshot per domain (all we have today) or a full session
/// history later.
struct DomainScore: Codable, Hashable {
    let domain: CognitiveDomain
    let value: Double
    let recordedAt: Date
}
