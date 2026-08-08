import SwiftUI

@main
struct SpatialRehabApp: App {
    /// Session for the "Making Tea" prototype task's `ImmersiveSpace` scene below. Not
    /// currently reachable from `ContentView` — its "Get Started" flow is disabled while
    /// baseline-metrics is the active focus (see `ContentView.swift`) — but kept declared
    /// here so the scene/session still exist for teammates continuing that work.
    @StateObject private var teaSession = TaskSession(steps: TeaTaskContent.steps)

    /// Gates the baseline assessment within a single run: starts `false` every launch, flips
    /// to `true` once the person finishes (or exits) the battery, so the rest of that session
    /// goes to the normal welcome/tea-task flow. Plain `@State`, not persisted, **for now** —
    /// while this is under active development it's more useful to see the assessment on
    /// every launch than to have it silently skip itself after the first run. Swap back to
    /// `@AppStorage("baseline.hasCompletedBaseline")` once the battery is stable and this
    /// should genuinely be a one-time, first-launch-only flow again.
    @State private var hasCompletedBaseline = false
    @State private var baselineSession = BaselineAssessmentSession()

    /// Pinned to `.mixed` (passthrough + virtual content composited together) so this stays
    /// genuinely augmented reality, never a fully-enclosing virtual environment. `.mixed` is
    /// the platform default when unset, but it's declared explicitly here so that's a
    /// guarantee, not an assumption.
    @State private var immersionStyle: any ImmersionStyle = .mixed

    var body: some Scene {
        WindowGroup {
            if hasCompletedBaseline {
                ContentView()
            } else {
                BaselineAssessmentView(session: baselineSession, onFinished: {
                    hasCompletedBaseline = true
                })
            }
        }
        // Taller than the original 600 so `ClockDrawingView`'s canvas + prompt + buttons fit
        // without clipping; other screens are centered content and just get extra margin.
        .defaultSize(width: 900, height: 780)

        ImmersiveSpace(id: ImmersiveSpaceID.teaTask) {
            ImmersiveTaskView(session: teaSession)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)
    }
}

/// Centralized so the window and the space agree on the identifier.
enum ImmersiveSpaceID {
    static let teaTask = "TeaTaskSpace"
}
