import SwiftUI

/// Basic mental-sums game: step through a short list of addition problems, tapping the
/// correct sum from a few choices — no typing, consistent with the rest of this app.
///
/// Correctness is recorded silently (`ArithmeticAnswer.isCorrect`) but never shown to the
/// patient: a tap simply advances to the next problem, no color-coded right/wrong feedback,
/// matching errorless-learning intent elsewhere in this battery. See
/// `Docs/BaselineAssessment_Design.md`.
struct ArithmeticGameView: View {
    let onComplete: (ArithmeticResult) -> Void

    /// Default reproduces the fixed baseline-battery problem list exactly, so the existing
    /// call site (`ArithmeticGameView(onComplete:)`) is unchanged. `DailyPracticeHubView`
    /// passes tier-scaled, freshly generated problems instead — see `PracticeDifficulty`.
    var problems: [BaselineAssessmentContent.Arithmetic.Problem] = BaselineAssessmentContent.Arithmetic.problems

    @State private var currentIndex = 0
    @State private var answers: [ArithmeticAnswer] = []
    @State private var shuffledChoices: [Int] = []

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("Problem \(currentIndex + 1) of \(problems.count)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                ProgressView(value: Double(currentIndex), total: Double(problems.count))
                    .frame(maxWidth: 200)
            }

            Text(problems[currentIndex].promptText)
                .font(.system(size: 40, weight: .semibold, design: .rounded))

            VStack(spacing: 16) {
                ForEach(shuffledChoices, id: \.self) { choice in
                    Button {
                        select(choice)
                    } label: {
                        Text("\(choice)")
                            .font(.title2.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 16))
                    .tint(.accentColor)
                }
            }
            .frame(maxWidth: 360)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { shuffledChoices = problems[currentIndex].choices.shuffled() }
    }

    private func select(_ choice: Int) {
        SoundEffects.playTap()

        let problem = problems[currentIndex]
        answers.append(
            ArithmeticAnswer(promptText: problem.promptText, correctAnswer: problem.correctAnswer, selectedAnswer: choice)
        )

        if currentIndex == problems.count - 1 {
            SoundEffects.playSuccess()
            onComplete(ArithmeticResult(answers: answers, completedAt: .now))
        } else {
            currentIndex += 1
            shuffledChoices = problems[currentIndex].choices.shuffled()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ArithmeticGameView(onComplete: { _ in })
}
