import Foundation

/// A single arithmetic problem's outcome. Correctness is tracked silently for later
/// caregiver review — never surfaced as right/wrong to the patient in the UI (errorless
/// learning).
struct ArithmeticAnswer: Codable, Hashable {
    let promptText: String
    let correctAnswer: Int
    let selectedAnswer: Int

    var isCorrect: Bool { selectedAnswer == correctAnswer }
}

/// Result of the basic-mental-sums baseline trial.
struct ArithmeticResult: Codable, Hashable {
    let answers: [ArithmeticAnswer]
    let completedAt: Date

    var score: Double {
        guard !answers.isEmpty else { return 0 }
        return Double(answers.filter(\.isCorrect).count) / Double(answers.count)
    }
}
