import SwiftUI

/// The floating instruction card shown during a guided task.
///
/// Kept deliberately plain for a dementia-care audience: one instruction at a time, large
/// text, one obvious primary action, dots instead of "step X of Y" for progress. See
/// `Docs/TaskDesign_MakingTea.md` for the reasoning.
struct GuidanceCardView: View {
    @ObservedObject var session: TaskSession

    var body: some View {
        VStack(spacing: 24) {
            if session.isComplete {
                completionContent
            } else {
                stepContent
            }
        }
        .padding(32)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var stepContent: some View {
        VStack(spacing: 20) {
            ProgressDots(progress: session.progress)

            Text(session.currentStep.instructionText)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 12) {
                Button(action: session.advance) {
                    Text("Done")
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)

                HStack(spacing: 12) {
                    if session.currentIndex > 0 {
                        Button("Back", action: session.goBack)
                            .buttonStyle(.bordered)
                    }
                    if session.currentStep.isOptional {
                        Button("Skip", action: session.advance)
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var completionContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("All done — enjoy your tea!")
                .font(.system(size: 26, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            Button("Start Again", action: session.reset)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }
}

private struct ProgressDots: View {
    let progress: (completed: Int, total: Int)

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<progress.total, id: \.self) { index in
                Circle()
                    .fill(index <= progress.completed - 1 || index == progress.completed ? dotColor(for: index) : Color.secondary.opacity(0.25))
                    .frame(width: index == progress.completed ? 12 : 9, height: index == progress.completed ? 12 : 9)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        index < progress.completed ? .green : .accentColor
    }
}

#Preview(windowStyle: .automatic) {
    GuidanceCardView(session: TaskSession(steps: TeaTaskContent.steps))
}
