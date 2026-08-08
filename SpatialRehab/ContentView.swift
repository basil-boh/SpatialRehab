import SwiftUI

/// Home screen: the "Remember the Way" exercise from `feature/wayfinding-activities`,
/// reached once `SpatialRehabApp.hasCompletedBaseline` flips to true. A small secondary
/// button opens `CaregiverDashboardView` (from the baseline-metrics branch) without
/// competing with the primary "Start" action.
///
/// Reconciled 2026-08-08, twice: first when both branches had independently rewritten
/// `ContentView` as the app's home screen (this branch's activity picker vs.
/// baseline-metrics' caregiver check-in card — Basil chose the activity picker), then again
/// after a teammate's follow-up commit simplified the picker down to a single activity
/// (Touch the Dots / Walk to the Bakery / Find Your Way Home were removed). The caregiver
/// dashboard button carries forward unchanged across both reconciliations.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var showingDashboard = false

    var body: some View {
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
                showingDashboard = true
            } label: {
                Label("Caregiver Dashboard", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)
        }
    }

    /// Deliberately generic, not step-specific — `RouteMemoryTableView.controlPanel` (the
    /// floating panel in the immersive space itself) already shows the real, phase-accurate
    /// instruction ("Take your time…", "Tap the corners…", the score feedback) plus the
    /// actual buttons. This flat window used to duplicate that with its own static "Look at
    /// the table / Study the glowing route…" text that never updated as the exercise
    /// progressed — two competing, sometimes-contradictory instruction panels floating at
    /// once. Combined into one: the immersive panel is now the single source of "what do I
    /// do right now," and this window just points the person toward it.
    private var inActivity: some View {
        VStack(spacing: 16) {
            Text("Look around you")
                .font(.system(size: 44, weight: .semibold))
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
                Task { await startActivity() }
            }
            .font(.title2)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
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
