import SwiftUI

/// Home screen shown after the baseline assessment finishes.
///
/// Redesigned (2026-08-08) after a low-fidelity mockup: a simple personal-greeting card
/// (time-aware greeting, one section label, one subtitle, primary actions, one stat) —
/// adapted into this app's existing visual language (rounded-rect `regularMaterial` card,
/// SF Rounded type) rather than the mockup's literal dashed-border/monospace wireframe
/// styling, which reads as a content sketch, not a spec to replicate pixel-for-pixel.
///
/// The AR "Making Tea" guided task (previously launched from here via the immersive space)
/// is disabled while baseline-metrics is the active focus — see
/// `Docs/BaselineAssessment_Design.md`. `SpatialRehabApp` still declares the `ImmersiveSpace`
/// scene and owns `teaSession`, so that work isn't deleted, just not entered from here for
/// now. Two primary actions from here: **Daily Practice** — the repeatable, leveled version
/// of the baseline mini-games, see `Docs/DailyPractice_Design.md` — and **View Progress**,
/// which opens `CaregiverDashboardView`, a real feature now (trend charts across sessions),
/// not the dev preview it used to be; the raw `BaselineResultsDebugView` dump moved to a
/// toolbar button inside that dashboard instead of being reachable directly from here.
struct ContentView: View {
    @State private var showingDashboard = false
    @State private var showingDailyPractice = false

    private var timeAwareGreeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        default: "Good evening"
        }
    }

    var body: some View {
        Group {
            if showingDailyPractice {
                DailyPracticeHubView(onExit: { showingDailyPractice = false })
            } else {
                homeCard
            }
        }
    }

    private var homeCard: some View {
        VStack(spacing: 28) {
            Text(timeAwareGreeting)
                .font(.system(size: 40, weight: .semibold, design: .rounded))

            VStack(spacing: 10) {
                Label {
                    Text("TODAY'S CHECK-IN")
                        .font(.caption.weight(.bold))
                        .kerning(1.2)
                } icon: {
                    Image(systemName: "checklist")
                }
                .foregroundStyle(.secondary)

                Text("Let's see how today's activities went.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button("Daily Practice") {
                    showingDailyPractice = true
                }
                .font(.title2)
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)

                Button("View Progress") {
                    showingDashboard = true
                }
                .font(.title3)
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Label(
                "\(BaselineResultsStore.completedGameCount()) of \(BaselineAssessmentSession.Phase.gameCount) activities completed",
                systemImage: "leaf.fill"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(48)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingDashboard) {
            CaregiverDashboardView()
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
