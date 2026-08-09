import SwiftUI

@main
struct SpatialRehabApp: App {
    /// Session for the "Making Tea" prototype task's `ImmersiveSpace` scene below. Not
    /// currently reachable from the UI — this predates `AppModel`'s activity system (the
    /// baseline-metrics and wayfinding-activities branches diverged before either saw the
    /// other's work), so nothing routes to it right now. Kept declared, not deleted, so the
    /// scene/session still exist for teammates continuing that work.
    @StateObject private var teaSession = TaskSession(steps: TeaTaskContent.steps)

    /// Gates the baseline assessment within a single run: starts `false` every launch, flips
    /// to `true` once the person finishes (or exits) the battery, so the rest of that session
    /// goes to the normal Remember the Way home screen (`ContentView`). Plain `@State`, not
    /// persisted, **for now** — while this is under active development it's more useful to
    /// see the assessment on every launch than to have it silently skip itself after the
    /// first run. Swap back to `@AppStorage("baseline.hasCompletedBaseline")` once the
    /// battery is stable and this should genuinely be a one-time, first-launch-only flow
    /// again.
    @State private var hasCompletedBaseline = false
    @State private var baselineSession = BaselineAssessmentSession()

    /// Shared state for the wayfinding-activities branch's Remember the Way exercise
    /// (session phase, the route-memory sub-model, voice guidance).
    @State private var appModel = AppModel()

    /// Pinned to `.mixed` for the tea-task space specifically (see `teaSession` above) —
    /// separate from `appModel`'s own immersion style below, since the two systems don't
    /// share a space.
    @State private var immersionStyle: any ImmersionStyle = .mixed

    /// Session for the "Who am I?" name-card / family-tree flow from the szehao-id-card
    /// branch — its own top-level windows, unrelated to `appModel`'s activity system.
    @State private var whoAmISession = WhoAmISessionModel()

    var body: some Scene {
        // Explicit id so `ContentView`/`RouteMemoryTableView` can dismiss and reopen this
        // specific window around the immersive activity (see `SceneID.main`) — a
        // `WindowGroup` with no id can't be targeted by `dismissWindow`/`openWindow`.
        WindowGroup(id: SceneID.main) {
            if hasCompletedBaseline {
                ContentView()
                    .environment(appModel)
            } else {
                BaselineAssessmentView(session: baselineSession, onFinished: {
                    hasCompletedBaseline = true
                })
            }
        }
        // Taller than the wayfinding branch's 600 so `ClockDrawingView`'s canvas + prompt +
        // buttons fit without clipping during the baseline battery; the activity-picker
        // screens shown once baseline is done are centered content and just get extra margin.
        .defaultSize(width: 900, height: 780)

        ImmersiveSpace(id: AppModel.activitySpaceID) {
            RouteMemoryTableView()
                .environment(appModel)
        }
        .immersionStyle(
            selection: Binding(
                get: { appModel.routeMemoryInside ? .full : .mixed },
                set: { _ in }
            ),
            in: .mixed, .full
        )

        ImmersiveSpace(id: ImmersiveSpaceID.teaTask) {
            ImmersiveTaskView(session: teaSession)
        }
        .immersionStyle(selection: $immersionStyle, in: .mixed)

        WindowGroup(id: "hummingbird") {
            HummingbirdVolumeView()
        }
        .windowStyle(.volumetric)
        .defaultSize(width: 0.6, height: 0.6, depth: 0.6, in: .meters)

        // “Who am I?” — nest + circle summon (name card opens as a second window).
        WindowGroup(id: "who-am-i") {
            WhoAmIView()
                .environment(whoAmISession)
        }
        .defaultSize(width: 1100, height: 720)

        WindowGroup(id: "name-card") {
            NameCardView(session: whoAmISession)
        }
        .defaultSize(width: 660, height: 760)
    }
}

/// Centralized so the window and the space agree on the identifier.
enum ImmersiveSpaceID {
    static let teaTask = "TeaTaskSpace"
}

/// Centralized so call sites dismissing/reopening the main window agree on the identifier.
enum SceneID {
    static let main = "MainWindow"
}
