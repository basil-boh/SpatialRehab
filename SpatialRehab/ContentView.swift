import SwiftUI

/// Home screen: an activity picker ("What shall we do today?") from the
/// `feature/wayfinding-activities` branch, reached once
/// `SpatialRehabApp.hasCompletedBaseline` flips to true. A small secondary button opens
/// `CaregiverDashboardView` (from the baseline-metrics branch) without competing with the
/// four primary activity choices.
///
/// Reconciled 2026-08-08: both branches independently rewrote `ContentView` as the app's
/// home screen for different purposes (this activity picker vs. baseline-metrics' caregiver
/// check-in card). Basil chose this branch's activity picker as the real home screen, with
/// the dashboard demoted to a secondary button here rather than the other way around.
struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var showingDashboard = false

    var body: some View {
        Group {
            if appModel.phase == .inActivity && appModel.currentActivity == .findHome {
                FindHomeView()
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            appModel.findHome.prepare()
            if #available(visionOS 26.0, *) {
                SpatialStreetCache.shared.warm(appModel.findHome.orderedSnapshotURLs)
            }
        }
        .onChange(of: appModel.findHome.orderedSnapshotURLs) { _, urls in
            if #available(visionOS 26.0, *) {
                SpatialStreetCache.shared.warm(urls)
            }
        }
        .sheet(isPresented: $showingDashboard) {
            CaregiverDashboardView()
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
                activityButton(
                    "Touch the Dots",
                    systemImage: "hand.tap.fill",
                    activity: .touchTheDots
                )
                activityButton(
                    "Walk to the Bakery",
                    systemImage: "figure.walk",
                    activity: .wayfinding
                )
                activityButton(
                    "Find Your Way Home",
                    systemImage: "house.fill",
                    activity: .findHome
                )
                activityButton(
                    "Remember the Way",
                    systemImage: "scribble.variable",
                    activity: .routeMemory
                )
            }

            Button {
                showingDashboard = true
            } label: {
                Label("Caregiver Dashboard", systemImage: "chart.line.uptrend.xyaxis")
            }
            .buttonStyle(.bordered)
        }
    }

    private func activityButton(
        _ title: String,
        systemImage: String,
        activity: AppModel.ActivityKind
    ) -> some View {
        Button {
            Task { await startActivity(activity) }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.title2)
                .frame(maxWidth: 380)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.extraLarge)
        .disabled(appModel.phase == .openingActivity)
    }

    private var inActivity: some View {
        VStack(spacing: 16) {
            Text("Look around you")
                .font(.system(size: 44, weight: .semibold))

            Text(inActivityGuidance)
            .font(.title2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
    }

    private var inActivityGuidance: String {
        switch appModel.currentActivity {
        case .touchTheDots:
            return "Touch the glowing circle when you see it."
        case .wayfinding:
            return "Follow the glowing circles. Cross only when the light is green."
        case .findHome:
            return "Which way is home? Choose with the arrows below."
        case .routeMemory:
            return "Study the glowing route on the table, then draw it from memory."
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

                Text("That was a lovely warm-up. See you again soon.")
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
        }
    }

    private func startActivity(_ activity: AppModel.ActivityKind) async {
        appModel.currentActivity = activity
        appModel.phase = .openingActivity
        switch activity {
        case .touchTheDots:
            appModel.dotsGame.reset()
        case .findHome:
            appModel.findHome.begin()
        case .routeMemory:
            appModel.routeMemory.begin()
        case .wayfinding:
            break
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
