import Foundation

/// A single orientation question's outcome, recorded silently like `ArithmeticAnswer` — no
/// right/wrong feedback shown to the patient.
struct OrientationAnswer: Codable, Hashable {
    let promptText: String
    let correctAnswer: String
    let selectedAnswer: String

    var isCorrect: Bool { selectedAnswer == correctAnswer }
}

/// Result of the orientation baseline trial (day of week / time of day / month).
struct OrientationResult: Codable, Hashable {
    let answers: [OrientationAnswer]
    let completedAt: Date

    var score: Double {
        guard !answers.isEmpty else { return 0 }
        return Double(answers.filter(\.isCorrect).count) / Double(answers.count)
    }
}
