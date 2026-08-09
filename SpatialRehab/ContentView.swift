import SwiftUI

/// Home screen: the "Remember the Way" exercise from `feature/wayfinding-activities`,
/// reached once `SpatialRehabApp.hasCompletedBaseline` flips to true. Secondary buttons
/// below the primary "Start" action open `DailyPracticeHubView` (the repeatable, leveled
/// version of the baseline mini-games — from the baseline-metrics branch, see
/// `Docs/DailyPractice_Design.md`) and `CaregiverDashboardView` (trend charts across
/// sessions, also from baseline-metrics), without competing with "Start" for attention.
///
/// Reconciled 2026-08-08, three times: first when both branches had independently rewritten
/// `ContentView` as the app's home screen (this branch's activity picker vs.
/// baseline-metrics' caregiver check-in card — Basil chose the activity picker), then again
/// after a teammate's follow-up commit simplified the picker down to a single activity
/// (Touch the Dots / Walk to the Bakery / Find Your Way Home were removed), then again after
/// baseline-metrics grew a Daily Practice hub and replaced its own home screen with a
/// greeting card — folded in here as a secondary "Daily Practice" entry point rather than
/// adopting the greeting-card layout, so the single-activity focus from the second
/// reconciliation still stands.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.openWindow) private var openWindow
    @State private var showingDashboard = false
    @State private var showingDailyPractice = false

    var body: some View {
        Group {
            if showingDailyPractice {
                DailyPracticeHubView(onExit: { showingDailyPractice = false })
            } else {
                VStack(spacing: 40) {
                    switch appModel.phase {
                    case .welcome, .openingActivity:
                        welcome
                    case .inActivity:
                        inActivity
                    case .finished:
                        finished
                    }
                }
                .padding(60)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $showingDashboard) {
                    CaregiverDashboardView()
                }
            }
        }
    }

    private var welcome: some View {
        VStack(spacing: 40) {
            Image(systemName: "map.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Remember the Way")
                    .font(.system(size: 44, weight: .semibold))

                Text("Watch the way home on the table, then find it again — and step into the street itself.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 560)
            }

            Button("Start") {
                Task { await startActivity() }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            .disabled(appModel.phase == .openingActivity)

            Button {
                showingDailyPractice = true
            } label: {
                Label("Daily Practice", systemImage: "checklist")
            }
            .buttonStyle(.bordered)

            Button {
                showingDashboard = true
            } label: {
                Label("Caregiver Dashboard", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)

            Button {
                openWindow(id: "who-am-i")
            } label: {
                Label("Who am I?", systemImage: "person.crop.circle")
            }
            .buttonStyle(.bordered)
            .tint(.orange)

            Button {
                openWindow(id: "hummingbird")
            } label: {
                Label("Hummingbird", systemImage: "bird.fill")
            }
            .buttonStyle(.bordered)
        }
    }

    /// Empty on purpose — `RouteMemoryTableView.controlPanel` (the floating panel in the
    /// immersive space itself) already shows the real, phase-accurate instruction ("Take
    /// your time…", "Tap the corners…", the score feedback) plus the actual buttons. This
    /// flat window used to duplicate that with its own text (first specific and stale, then
    /// a generic "Look around you") floating alongside the immersive panel — still a second
    /// surface competing for attention even once it stopped saying anything wrong. Now it
    /// shows nothing at all while the person's in the activity; the immersive panel is the
    /// only thing there.
    private var inActivity: some View {
        EmptyView()
    }

    private var finished: some View {
        VStack(spacing: 40) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 16) {
                Text("Well done!")
                    .font(.system(size: 44, weight: .semibold))

                Text("You did wonderfully. See you again soon.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Play again") {
                Task { await startActivity() }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)

            HStack(spacing: 16) {
                Button {
                    showingDailyPractice = true
                } label: {
                    Label("Daily Practice", systemImage: "checklist")
                }
                .buttonStyle(.bordered)

                Button {
                    showingDashboard = true
                } label: {
                    Label("Caregiver Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .buttonStyle(.bordered)

                Button {
                    openWindow(id: "who-am-i")
                } label: {
                    Label("Who am I?", systemImage: "person.crop.circle")
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Button {
                    openWindow(id: "hummingbird")
                } label: {
                    Label("Hummingbird", systemImage: "bird.fill")
                }
                .buttonStyle(.bordered)
            }

            Label(
                "\(BaselineResultsStore.completedGameCount()) of \(BaselineAssessmentSession.Phase.gameCount) activities completed",
                systemImage: "leaf.fill"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func startActivity() async {
        appModel.phase = .openingActivity
        appModel.routeMemory.begin()
        switch await openImmersiveSpace(id: AppModel.activitySpaceID) {
        case .opened:
            appModel.phase = .inActivity
        case .userCancelled, .error:
            appModel.phase = .welcome
        @unknown default:
            appModel.phase = .welcome
        }
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
