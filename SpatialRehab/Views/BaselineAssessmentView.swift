import SwiftUI

/// Root view for the first-launch baseline assessment battery.
///
/// Never shows a score to the patient — even a simple tally could read as pass/fail, which
/// conflicts with the errorless-learning no-punishment intent that runs through this app.
/// A low-visual-weight "Exit for now" affordance is present on every phase; exiting calls
/// `onFinished` directly and skips the summary affirmation, since an opted-out run shouldn't
/// look like a completed one. See `Docs/BaselineAssessment_Design.md`.
struct BaselineAssessmentView: View {
    let session: BaselineAssessmentSession
    let onFinished: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            switch session.phase {
            case .intro:
                introContent
            case .wordMemory:
                WordMemoryGameView(onComplete: session.completeWordMemory)
            case .patternMatching:
                PatternMatchingGameView(onComplete: session.completePatternMatching)
            case .arithmetic:
                ArithmeticGameView(onComplete: session.completeArithmetic)
            case .clockDrawing:
                ClockDrawingView(onComplete: session.completeClockDrawing)
            case .summary:
                summaryContent
            }

            if session.phase != .summary {
                Button("Exit for now", action: onFinished)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var introContent: some View {
        VStack(spacing: 32) {
            Image(systemName: "checklist")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("A Few Quick Activities")
                    .font(.system(size: 36, weight: .semibold))
                    .multilineTextAlignment(.center)

                Text("Before we get started, let's do a few short activities together. There are no right or wrong answers — just do your best.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            Button("Begin", action: session.begin)
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
        }
    }

    private var summaryContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)

            Text("Thank you — that's everything for now.")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)

            Button("Continue", action: onFinished)
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
        }
    }
}

#Preview(windowStyle: .automatic) {
    BaselineAssessmentView(session: BaselineAssessmentSession(), onFinished: {})
}
