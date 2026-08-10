import Foundation
import Observation

/// Guided coffee-making — an activity-of-daily-living sequence (procedural
/// memory, task sequencing). Errorless: the next item is always shown and
/// demonstrated; wrong picks are redirected gently and counted invisibly.
@Observable
@MainActor
final class CoffeeExercise {
    enum Step: Int, CaseIterable, Equatable {
        case water
        case coffee
        case sugar
        case milk
        case stir

        var instruction: String {
            switch self {
            case .water: return "Pick up the kettle and pour the hot water into the mug."
            case .coffee: return "Pick up the coffee tin and tip the coffee into the mug."
            case .sugar: return "Pick up the sugar bowl and pour in a little sugar."
            case .milk: return "Pick up the milk jug and pour in the milk."
            case .stir: return "Pick up the teaspoon and stir it all together."
            }
        }

        var praise: String {
            switch self {
            case .water: return "Lovely."
            case .coffee: return "That smells good already."
            case .sugar: return "Just right."
            case .milk: return "Perfect."
            case .stir: return "Wonderful."
            }
        }

        var itemName: String {
            switch self {
            case .water: return "the kettle"
            case .coffee: return "the coffee tin"
            case .sugar: return "the sugar bowl"
            case .milk: return "the milk jug"
            case .stir: return "the teaspoon"
            }
        }

        /// Said instead of the full instruction at the lightest guidance level:
        /// enough to name the step, not enough to walk her through it.
        var shortInstruction: String {
            switch self {
            case .water: return "The water first."
            case .coffee: return "Now the coffee."
            case .sugar: return "Now the sugar."
            case .milk: return "Now the milk."
            case .stir: return "And give it a stir."
            }
        }
    }

    /// How much help she asked for before starting.
    ///
    /// The levels fade the *cues*, never the task itself. Errorless learning means
    /// support has to arrive before a mistake can happen, so every level still ends
    /// up offering the full demonstration; the lighter levels simply wait longer
    /// before doing it, and go quiet again the moment she picks the right thing up.
    /// Nothing here is ever withheld as a test.
    enum GuidanceLevel: String, CaseIterable, Identifiable, Equatable {
        case showMe
        case hints
        case onMyOwn

        var id: String { rawValue }

        var title: String {
            switch self {
            case .showMe: return "Show me how"
            case .hints: return "A little hint"
            case .onMyOwn: return "Let me try myself"
            }
        }

        var detail: String {
            switch self {
            case .showMe: return "I'll talk you through every step and show you how it's done."
            case .hints: return "I'll point out what's next, and show you if you'd like a moment."
            case .onMyOwn: return "I'll stay quiet, and step in only if you'd like a hand."
            }
        }

        var symbolName: String {
            switch self {
            case .showMe: return "hand.point.up.left.fill"
            case .hints: return "lightbulb.fill"
            case .onMyOwn: return "figure.stand"
            }
        }

        /// Spoken once as the activity opens. Only the fullest level lays out the
        /// whole recipe; the others would be giving away the sequence she came to
        /// practise.
        var openingLine: String? {
            switch self {
            case .showMe:
                return "Let's make a kopi together. Water first, then the coffee, "
                    + "a little sugar, the milk, and a stir at the end."
            case .hints:
                return "Let's make a kopi. I'll point things out as we go."
            case .onMyOwn:
                return "Let's make a kopi. Take your time."
            }
        }

        func spokenInstruction(for step: Step) -> String {
            self == .onMyOwn ? step.shortInstruction : step.instruction
        }

        /// Seconds a step may run before each cue joins in. Measured from the moment
        /// the step becomes current, and reset whenever she puts the item back down,
        /// so cues escalate for someone who is stuck and stay away from someone who
        /// is getting on with it.
        var cueSchedule: CueSchedule {
            switch self {
            case .showMe: return CueSchedule(halo: 0, arrow: 0.3, path: 0.9, demo: 1.6)
            case .hints: return CueSchedule(halo: 0, arrow: 5, path: 11, demo: 20)
            case .onMyOwn: return CueSchedule(halo: 12, arrow: 20, path: 28, demo: 36)
            }
        }
    }

    /// When each guidance cue appears within a step, in seconds.
    struct CueSchedule: Equatable {
        let halo: TimeInterval
        let arrow: TimeInterval
        let path: TimeInterval
        let demo: TimeInterval
    }

    enum Phase: Equatable {
        /// Before anything is poured: she picks how much help she wants.
        case choosingGuidance
        case brewing
        case finished
    }

    private(set) var phase: Phase = .choosingGuidance
    /// Held at `.water` rather than nil while she is still choosing, so the home
    /// window's step dots and instruction line show the first step instead of
    /// falling through to their "kopi is ready" copy.
    private(set) var currentStep: Step? = .water
    private(set) var guidance: GuidanceLevel = .showMe
    private(set) var wrongPicks = 0
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?

    func begin() {
        phase = .choosingGuidance
        currentStep = .water
        wrongPicks = 0
        startedAt = nil
        completedAt = nil
    }

    /// Leaves the chooser and starts the first step. `startedAt` is stamped here
    /// rather than in `begin()` so time spent reading the options doesn't count
    /// against her on the caregiver's timeline.
    func startBrewing(with level: GuidanceLevel) {
        guidance = level
        phase = .brewing
        currentStep = .water
        startedAt = .now
    }

    func isCurrent(_ step: Step) -> Bool {
        currentStep == step
    }

    func recordWrongPick() {
        wrongPicks += 1
    }

    func completeCurrentStep() {
        guard let step = currentStep else { return }
        if let next = Step(rawValue: step.rawValue + 1) {
            currentStep = next
        } else {
            currentStep = nil
            phase = .finished
            completedAt = .now
        }
    }
}
