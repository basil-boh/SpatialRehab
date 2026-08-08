import Foundation

/// A cognitive-stimulation exercise `GameRecommendationEngine` can point a session toward.
///
/// Metadata only — title, targeted domain, and a caregiver-facing summary. The actual
/// game views are separate, unbuilt work (see the activity-mapping table in the
/// product-vision doc); the engine just needs something concrete to recommend today,
/// so a teammate wiring up the real game later has a title/domain pair to match against.
struct StimulationGame: Codable, Hashable, Identifiable {
    var id: String { title }
    let title: String
    let domain: CognitiveDomain
    let summary: String
}

/// The fixed set of stimulation games `GameRecommendationEngine` can recommend, grouped
/// by the domain each one targets.
///
/// Titles and domain mapping follow the ability→exercise table in the product-vision
/// doc, narrowed to the domains the baseline battery can currently score
/// (see `CognitiveDomain`). Content (copy, difficulty) is a placeholder pending
/// clinical review, same as the rest of the baseline battery.
enum StimulationGameCatalog {
    static let all: [StimulationGame] = [
        StimulationGame(
            title: "Today in Review",
            domain: .memory,
            summary: "Recaps the day's completed routine steps to support recent-event memory."
        ),
        StimulationGame(
            title: "Remember To…",
            domain: .memory,
            summary: "A prospective-memory prompt set earlier in the session and revisited later."
        ),
        StimulationGame(
            title: "Virtual Hawker Centre",
            domain: .numeracy,
            summary: "Practises totals and change-making while ordering in a familiar setting."
        ),
        StimulationGame(
            title: "Safe Shopping Simulation",
            domain: .numeracy,
            summary: "Practises budgeting a purchase, a financial IADL that gets harder as numeracy declines."
        ),
        StimulationGame(
            title: "What Comes Next?",
            domain: .executiveFunction,
            summary: "Sequencing support for a multi-step task, for when the thread gets lost partway through."
        ),
        StimulationGame(
            title: "Plan & Prepare Dinner",
            domain: .executiveFunction,
            summary: "Executive-function planning support for a routine many patients can no longer plan alone."
        ),
    ]

    static func games(for domain: CognitiveDomain) -> [StimulationGame] {
        all.filter { $0.domain == domain }
    }
}
