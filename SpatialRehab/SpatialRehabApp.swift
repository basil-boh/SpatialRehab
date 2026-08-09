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
    /// branch — shared with the persistent `WhoAmIButton` (main-window ornament + the
    /// Remember the Way control panel) and the `name-card` window below; unrelated to
    /// `appModel`'s own activity system.
    @State private var whoAmISession = WhoAmISessionModel()

    var body: some Scene {
        // Explicit id so `ContentView`/`RouteMemoryTableView` can dismiss and reopen this
        // specific window around the immersive activity (see `SceneID.main`) — a
        // `WindowGroup` with no id can't be targeted by `dismissWindow`/`openWindow`.
        WindowGroup(id: SceneID.main) {
            if hasCompletedBaseline {
                ContentView()
                    // Persistent "Who am I?" affordance for dementia patients: a bottom
                    // ornament rides the window itself, so it stays in the same spot on
                    // every screen this window shows (home, Daily Practice, the caregiver
                    // dashboard sheet) instead of living inside any one screen's layout.
                    // Deliberately absent from the baseline branch below — the assessment
                    // must not offer mid-test escapes — and from the `name-card` window,
                    // which is the card itself. `RouteMemoryTableView`'s control panel
                    // hosts the same button while this window is dismissed mid-activity.
                    .ornament(attachmentAnchor: .scene(.bottom)) {
                        WhoAmIButton()
                            .padding(12)
                            .glassBackgroundEffect()
                    }
                    .environment(appModel)
                    .environment(whoAmISession)
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
                // For the `WhoAmIButton` in the control panel — the main window (and its
                // ornament) is dismissed while this space is open, so the panel is the
                // only place left to reach the name card from.
                .environment(whoAmISession)
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

        // “Who am I?” name card — opened directly from the persistent `WhoAmIButton`, no
        // separate summon screen; `whoAmISession` is shared into both of that button's
        // hosts above so it can call `present()` before opening this.
        WindowGroup(id: SceneID.nameCard) {
            NameCardView(session: whoAmISession)
                // For the card's "Show me the way home" button, which starts the
                // Remember the Way activity via `AppModel.startWayHome`.
                .environment(appModel)
        }
        // Sized for the family-tree side: three generations at readable tile sizes were
        // clipping the edges of the old 660×760 window (user screenshot, 2026-08-09).
        .defaultSize(width: 900, height: 960)
    }
}

/// Centralized so the window and the space agree on the identifier.
enum ImmersiveSpaceID {
    static let teaTask = "TeaTaskSpace"
}

/// Centralized so call sites dismissing/reopening the main window agree on the identifier.
enum SceneID {
    static let main = "MainWindow"
    /// The “Who am I?” name-card window, opened by `WhoAmIButton` from either host.
    static let nameCard = "name-card"
}
