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
    @Environment(\.dismissWindow) private var dismissWindow
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
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            Text("What shall we do today?")
                .font(.system(size: 44, weight: .semibold))

            VStack(spacing: 20) {
                Button {
                    Task { await startActivity(.routeMemory) }
                } label: {
                    Label("Remember the Way", systemImage: "map.fill")
                        .font(.title2)
                        .frame(maxWidth: 400)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(appModel.phase == .openingActivity)

                Button {
                    Task { await startActivity(.coffee) }
                } label: {
                    Label("Make a Cup of Kopi", systemImage: "cup.and.saucer.fill")
                        .font(.title2)
                        .frame(maxWidth: 400)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(appModel.phase == .openingActivity)

                Button {
                    Task { await startActivity(.mahjong) }
                } label: {
                    Label("Play Mahjong Pairs", systemImage: "square.grid.3x3.fill")
                        .font(.title2)
                        .frame(maxWidth: 400)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.extraLarge)
                .disabled(appModel.phase == .openingActivity)
            }

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
            }
            // "Who am I?" is deliberately not in this stack — it lives in the main
            // window's bottom ornament (see `SpatialRehabApp`), so it sits in the same
            // spot on every screen instead of moving with each screen's layout.
        }
    }

    /// Guidance while the kopi or mahjong activity runs — those spaces keep this window
    /// open as their instruction surface. Unreachable for Remember the Way: that activity
    /// dismisses this whole window (`AppModel.startWayHome`) because
    /// `RouteMemoryTableView.controlPanel` already carries the real, phase-accurate
    /// instructions and a second surface just competed for attention.
    private var inActivity: some View {
        VStack(spacing: 16) {
            Text("Look at the table")
                .font(.system(size: 44, weight: .semibold))

            Text(inActivityGuidance)
                .font(.title2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
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
                Task { await startActivity(appModel.currentActivity) }
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
                // "Who am I?" lives in the window's bottom ornament, not here — see
                // the note on the welcome screen's button stack.
            }

            Label(
                "\(BaselineResultsStore.completedGameCount()) of \(BaselineAssessmentSession.Phase.gameCount) activities completed",
                systemImage: "leaf.fill"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var inActivityGuidance: String {
        switch appModel.currentActivity {
        case .routeMemory:
            return "Study the glowing route, then find the way home from memory."
        case .coffee:
            return "Follow the glowing tags and make your kopi, one step at a time."
        case .mahjong:
            return "Pick up a tile and place it beside its twin."
        }
    }

    private func startActivity(_ activity: AppModel.ActivityKind) async {
        // Remember the Way dismisses this window (its immersive control panel is the
        // only guidance surface) and is shared with the name card's "Show me the way
        // home" — see AppModel.startWayHome. Kopi and mahjong keep the window open as
        // their guidance surface (`inActivity` above).
        if activity == .routeMemory {
            await appModel.startWayHome(openImmersiveSpace: openImmersiveSpace, dismissWindow: dismissWindow)
            return
        }
        appModel.phase = .openingActivity
        appModel.currentActivity = activity
        switch activity {
        case .routeMemory:
            appModel.routeMemory.begin()
        case .coffee:
            appModel.coffee.begin()
        case .mahjong:
            appModel.mahjong.begin()
        }
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
