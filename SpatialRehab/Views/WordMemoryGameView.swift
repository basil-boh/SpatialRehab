import SwiftUI

/// The word-memory recognition game: study a short word list against a visible countdown,
/// then tap every word you remember from a shuffled grid of targets + distractors.
///
/// Kept deliberately low-friction for a dementia-care audience: large tap targets, no
/// typing, and no color-coded right/wrong feedback on taps — a tap just toggles "selected"
/// (shown as green, the only highlight color used), nothing in this view ever tells the
/// patient they got something wrong (errorless learning). Showing many options at once here
/// is inherent to recognition-format testing (it needs distractors to be meaningful) and is
/// a deliberate exception to this app's usual one-decision-at-a-time screens. See
/// `Docs/BaselineAssessment_Design.md`.
struct WordMemoryGameView: View {
    let onComplete: (WordMemoryTrial) -> Void

    /// Defaults reproduce the fixed baseline-battery content exactly, so every existing call
    /// site (`WordMemoryGameView(onComplete:)`) behaves byte-for-byte the same as before.
    /// `DailyPracticeHubView` passes tier-scaled content instead — see `PracticeDifficulty`.
    var targetWords: [String] = BaselineAssessmentContent.WordMemory.targetWords
    var distractorWords: [String] = BaselineAssessmentContent.WordMemory.distractorWords
    var studyDurationSeconds: TimeInterval = BaselineAssessmentContent.WordMemory.studyDurationSeconds

    private enum SubPhase {
        case study
        case recall
    }

    @State private var subPhase: SubPhase = .study
    @State private var tappedWords: Set<String> = []
    @State private var gridWords: [String] = []
    @State private var remainingSeconds = 0

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

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
            gridWords = (targetWords + distractorWords).shuffled()
            remainingSeconds = Int(studyDurationSeconds)
            while remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                remainingSeconds -= 1
            }
            subPhase = .recall
        }
    }

    private var studyContent: some View {
        VStack(spacing: 28) {
            Text("Remember these words")
                .font(.system(size: 32, weight: .semibold, design: .rounded))

            VStack(spacing: 16) {
                ForEach(targetWords, id: \.self) { word in
                    Text(word)
                        .font(.system(size: 28, weight: .medium))
                }
            }

            VStack(spacing: 10) {
                Text("\(remainingSeconds)")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: remainingSeconds)

                ProgressView(value: Double(remainingSeconds), total: Double(studyDurationSeconds))
                    .frame(maxWidth: 240)
            }
        }
    }

    private var recallContent: some View {
        VStack(spacing: 28) {
            Text("Tap the words you remember")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(gridWords, id: \.self) { word in
                    wordButton(word)
                }
            }

            Button("Done") {
                onComplete(
                    WordMemoryTrial(
                        targetWords: targetWords,
                        distractorWords: distractorWords,
                        tappedWords: tappedWords,
                        completedAt: .now
                    )
                )
            }
            .font(.title3.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
    }

    private func wordButton(_ word: String) -> some View {
        let isSelected = tappedWords.contains(word)
        return Button {
            SoundEffects.playSoftTap()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                if isSelected {
                    tappedWords.remove(word)
                } else {
                    tappedWords.insert(word)
                }
            }
        } label: {
            Text(word)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(isSelected ? .green : Color.gray.opacity(0.22))
        .scaleEffect(isSelected ? 1.06 : 1.0)
    }
}

#Preview(windowStyle: .automatic) {
    WordMemoryGameView(onComplete: { _ in })
}
