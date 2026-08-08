import Foundation
import Combine

/// Drives progression through a fixed list of `TaskStep`s.
///
/// Deliberately linear (no branching, no going "ahead") to match the errorless-learning
/// intent in `Docs/TaskDesign_MakingTea.md`: the person is only ever shown one step, and
/// completion is the only thing that advances it.
@MainActor
final class TaskSession: ObservableObject {
    let steps: [TaskStep]

    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isComplete: Bool = false

    init(steps: [TaskStep]) {
        precondition(!steps.isEmpty, "TaskSession requires at least one step")
        self.steps = steps.sorted { $0.order < $1.order }
    }

    var currentStep: TaskStep {
        steps[min(currentIndex, steps.count - 1)]
    }

    /// One filled dot per completed step, for the low-cognitive-load progress indicator.
    var progress: (completed: Int, total: Int) {
        (currentIndex, steps.count)
    }

    func advance() {
        guard !isComplete else { return }
        if currentIndex == steps.count - 1 {
            isComplete = true
        } else {
            currentIndex += 1
        }
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        isComplete = false
        currentIndex -= 1
    }

    func reset() {
        currentIndex = 0
        isComplete = false
    }
}
