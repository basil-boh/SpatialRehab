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
    }

    enum Phase: Equatable {
        case brewing
        case finished
    }

    private(set) var phase: Phase = .brewing
    private(set) var currentStep: Step? = .water
    private(set) var wrongPicks = 0
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?

    func begin() {
        phase = .brewing
        currentStep = .water
        wrongPicks = 0
        startedAt = .now
        completedAt = nil
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
