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

    /// Splits `.intro` into two screens shown one at a time: brand (logo, name, description)
    /// first, then the "A Few Quick Activities" explanation — rather than both stacked on one
    /// screen. Local to this view, not part of `BaselineAssessmentSession.Phase`, since it's
    /// pure intro-screen sequencing, not a real assessment phase worth persisting or resuming.
    private enum IntroStep {
        case brand
        case activities
    }

    @State private var introStep: IntroStep = .brand

    var body: some View {
        VStack(spacing: 24) {
            switch session.phase {
            case .intro:
                switch introStep {
                case .brand:
                    brandContent
                case .activities:
                    activitiesContent
                }
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

    private var brandContent: some View {
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

            Button("Next") {
                introStep = .activities
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
    }

    private var activitiesContent: some View {
        VStack(spacing: 28) {
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

    /// A faceted hexagon — a plain geometric mark rather than a metaphor for anything
    /// specific (not a window, not an orbit, not a place). Six triangular facets radiate
    /// from the center, each a different opacity of blue over an indigo base, so it reads
    /// as a cut, dimensional gem catching light from the upper-left rather than a flat
    /// hexagon outline. Drawn with `Canvas`, the same path-drawing primitive
    /// `ClockDrawingView` already uses elsewhere in this battery, rather than an imported
    /// SVG — Xcode can import a real SVG into the asset catalog as a scalable vector image,
    /// but authoring one by hand with no design tooling to preview it isn't a good trade for
    /// a logo; this gets the same crisp, resolution-independent scaling entirely in code.
    private var logoMark: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 4

            let vertices = (0..<6).map { index -> CGPoint in
                let angle = Angle.degrees(-90 + Double(index) * 60).radians
                return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            }

            var hexagon = Path()
            hexagon.addLines(vertices)
            hexagon.closeSubpath()
            context.fill(hexagon, with: .color(.indigo))

            // One opacity per facet (vertices[i] to vertices[i+1]), brightest at the
            // upper-left to read as a light source catching that corner of the gem.
            let facetOpacities: [Double] = [0.6, 0.4, 0.2, 0.15, 0.35, 0.8]
            for index in 0..<6 {
                var facet = Path()
                facet.move(to: center)
                facet.addLine(to: vertices[index])
                facet.addLine(to: vertices[(index + 1) % 6])
                facet.closeSubpath()
                context.fill(facet, with: .color(.blue.opacity(facetOpacities[index])))
            }

            var seams = Path()
            for vertex in vertices {
                seams.move(to: center)
                seams.addLine(to: vertex)
            }
            context.stroke(seams, with: .color(.white.opacity(0.25)), lineWidth: 1)
            context.stroke(hexagon, with: .color(.indigo), lineWidth: 2)
        }
        .frame(width: 92, height: 92)
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
