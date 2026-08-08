import SwiftUI

/// Digit-span working-memory game: watch a short digit sequence flash one digit at a time,
/// then tap it back in the same order on a number pad.
///
/// Order matters here (unlike the word-memory recognition grid), so recall is a build-up
/// sequence with free "Clear" retry rather than a toggle grid — consistent with this
/// battery's errorless-learning stance of never penalizing a retry. See
/// `Docs/BaselineAssessment_Design.md`.
struct DigitSpanGameView: View {
    let onComplete: (DigitSpanResult) -> Void

    private enum SubPhase {
        case study
        case recall
    }

    @State private var subPhase: SubPhase = .study
    @State private var revealedDigit: Int?
    @State private var enteredSequence: [Int] = []

    private let columns = [GridItem(.fixed(90)), GridItem(.fixed(90)), GridItem(.fixed(90))]

    var body: some View {
        VStack(spacing: 32) {
            switch subPhase {
            case .study:
                studyContent
            case .recall:
                recallContent
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            for digit in BaselineAssessmentContent.DigitSpan.sequence {
                revealedDigit = digit
                try? await Task.sleep(for: .seconds(BaselineAssessmentContent.DigitSpan.revealSecondsPerDigit))
                revealedDigit = nil
                try? await Task.sleep(for: .seconds(0.3))
            }
            subPhase = .recall
        }
    }

    private var studyContent: some View {
        VStack(spacing: 28) {
            Text("Watch the numbers")
                .font(.system(size: 32, weight: .semibold, design: .rounded))

            Text(revealedDigit.map(String.init) ?? "")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .frame(width: 140, height: 140)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .contentTransition(.numericText())
                .animation(.default, value: revealedDigit)
        }
    }

    private var recallContent: some View {
        VStack(spacing: 24) {
            Text("Tap the numbers in order")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                ForEach(Array(enteredSequence.enumerated()), id: \.offset) { _, digit in
                    Text("\(digit)")
                        .font(.title2.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.green.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                }
                ForEach(enteredSequence.count..<BaselineAssessmentContent.DigitSpan.sequence.count, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(.secondary.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 44, height: 44)
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...9, id: \.self) { digit in
                    numberButton(digit)
                }
                Color.clear.frame(width: 90, height: 60)
                numberButton(0)
                Color.clear.frame(width: 90, height: 60)
            }

            HStack(spacing: 16) {
                Button("Clear") { enteredSequence = [] }
                    .buttonStyle(.bordered)

                Button("Done") {
                    onComplete(
                        DigitSpanResult(
                            targetSequence: BaselineAssessmentContent.DigitSpan.sequence,
                            enteredSequence: enteredSequence,
                            completedAt: .now
                        )
                    )
                }
                .font(.title3.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(enteredSequence.count != BaselineAssessmentContent.DigitSpan.sequence.count)
            }
        }
    }

    private func numberButton(_ digit: Int) -> some View {
        Button {
            SoundEffects.playSoftTap()
            enteredSequence.append(digit)
        } label: {
            Text("\(digit)")
                .font(.title2.weight(.semibold))
                .frame(width: 90, height: 60)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .disabled(enteredSequence.count == BaselineAssessmentContent.DigitSpan.sequence.count)
    }
}

#Preview(windowStyle: .automatic) {
    DigitSpanGameView(onComplete: { _ in })
}
