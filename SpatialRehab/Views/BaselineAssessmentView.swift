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
            case .reactionTime:
                ReactionTimeGameView(onComplete: session.completeReactionTime)
            case .orientation:
                OrientationGameView(onComplete: session.completeOrientation)
            case .wordMemory:
                WordMemoryGameView(onComplete: session.completeWordMemory)
            case .digitSpan:
                DigitSpanGameView(onComplete: session.completeDigitSpan)
            case .patternMatching:
                PatternMatchingGameView(onComplete: session.completePatternMatching)
            case .trailMaking:
                TrailMakingGameView(onComplete: session.completeTrailMaking)
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
        VStack(spacing: 28) {
            logoMark

            VStack(spacing: 10) {
                Text("SpatialRehab")
                    .font(.system(size: 34, weight: .bold, design: .rounded))

                Text("A calm companion for cognitive exercises and guided wayfinding practice, right at home.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            VStack(spacing: 12) {
                Text("A Few Quick Activities")
                    .font(.system(size: 30, weight: .semibold))
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

    /// A simple mark built from SF Symbols + SwiftUI shapes rather than an imported SVG —
    /// Xcode can import a real SVG into the asset catalog as a scalable vector image, but
    /// authoring one by hand with no design tooling to preview it isn't a good trade for a
    /// logo; this achieves the same crisp, resolution-independent scaling entirely in code,
    /// verifiable the same way as everything else in this app. House silhouette over a
    /// gradient badge, echoing the wayfinding/"finding home" theme that runs through this
    /// app, in the same blue identity color used for the "Remember the Way" home screen's
    /// icon.
    private var logoMark: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "house.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 76, height: 76)
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
