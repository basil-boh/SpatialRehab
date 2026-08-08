import SwiftUI

/// Orientation game: three questions about the current day/time/month, tap the answer from
/// a few choices — no typing, same pattern as `ArithmeticGameView`.
///
/// Correctness is recorded silently and never shown to the patient: a tap simply advances
/// to the next question. See `Docs/BaselineAssessment_Design.md` for why "what season is
/// it?" is deliberately excluded from this set.
struct OrientationGameView: View {
    let onComplete: (OrientationResult) -> Void

    @State private var questions = BaselineAssessmentContent.Orientation.questions()
    @State private var currentIndex = 0
    @State private var answers: [OrientationAnswer] = []

    var body: some View {
        VStack(spacing: 32) {
            Text("Question \(currentIndex + 1) of \(questions.count)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(questions[currentIndex].promptText)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                ForEach(questions[currentIndex].choices, id: \.self) { choice in
                    Button {
                        select(choice)
                    } label: {
                        Text(choice)
                            .font(.title3.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .tint(.accentColor)
                }
            }
            .frame(maxWidth: 420)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func select(_ choice: String) {
        SoundEffects.playTap()

        let question = questions[currentIndex]
        answers.append(
            OrientationAnswer(promptText: question.promptText, correctAnswer: question.correctAnswer, selectedAnswer: choice)
        )

        if currentIndex == questions.count - 1 {
            onComplete(OrientationResult(answers: answers, completedAt: .now))
        } else {
            currentIndex += 1
        }
    }
}

#Preview(windowStyle: .automatic) {
    OrientationGameView(onComplete: { _ in })
}
