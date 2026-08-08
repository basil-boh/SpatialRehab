import SwiftUI

/// Reaction-time/attention warm-up: a shape appears at a random position after a random
/// delay (so it can't be anticipated), tap it as soon as you see it, repeated a few times.
///
/// Placed first in the battery as a literal warm-up, matching the "Touch the dots" /
/// hand-eye-coordination warm-up described in the product-vision doc. No score shown to
/// the patient — like `ClockDrawingResult`, raw reaction times don't normalize into a
/// percentage, so this reports the readings for a caregiver rather than forcing a grade.
struct ReactionTimeGameView: View {
    let onComplete: (ReactionTimeResult) -> Void

    @State private var trialIndex = 0
    @State private var reactionTimesMs: [Double] = []
    @State private var shapePosition: CGPoint = .zero
    @State private var shapeShownAt: Date?

    private let canvasSize = CGSize(width: 640, height: 420)

    var body: some View {
        VStack(spacing: 20) {
            Text("Trial \(trialIndex + 1) of \(BaselineAssessmentContent.ReactionTime.trialCount)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(shapeShownAt == nil ? "Get ready…" : "Tap it!")
                .font(.system(size: 30, weight: .semibold, design: .rounded))

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.regularMaterial)
                    .frame(width: canvasSize.width, height: canvasSize.height)

                if let shownAt = shapeShownAt {
                    Button {
                        registerTap(shownAt: shownAt)
                    } label: {
                        Image(systemName: BaselineAssessmentContent.ReactionTime.shapeSymbolName)
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                    .position(shapePosition)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await runTrial()
        }
    }

    private func runTrial() async {
        shapeShownAt = nil
        let delay = Double.random(
            in: BaselineAssessmentContent.ReactionTime.minDelaySeconds...BaselineAssessmentContent.ReactionTime.maxDelaySeconds
        )
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }

        shapePosition = CGPoint(
            x: .random(in: 60...(canvasSize.width - 60)),
            y: .random(in: 60...(canvasSize.height - 60))
        )
        shapeShownAt = .now
    }

    private func registerTap(shownAt: Date) {
        SoundEffects.playSoftTap()
        reactionTimesMs.append(Date.now.timeIntervalSince(shownAt) * 1000)
        shapeShownAt = nil

        if trialIndex == BaselineAssessmentContent.ReactionTime.trialCount - 1 {
            onComplete(ReactionTimeResult(reactionTimesMs: reactionTimesMs, completedAt: .now))
        } else {
            trialIndex += 1
            Task { await runTrial() }
        }
    }
}

#Preview(windowStyle: .automatic) {
    ReactionTimeGameView(onComplete: { _ in })
}
