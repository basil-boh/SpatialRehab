import SwiftUI

@main
struct SpatialRehabApp: App {
    /// Single shared session for the "Making Tea" prototype task. Owned at the app level so
    /// the 2D window (instructions) and the immersive space (spatial markers) stay in sync
    /// without any extra plumbing.
    @StateObject private var teaSession = TaskSession(steps: TeaTaskContent.steps)

    /// Pinned to `.mixed` (passthrough + virtual content composited together) so this stays
    /// genuinely augmented reality, never a fully-enclosing virtual environment. `.mixed` is
    /// the platform default when unset, but it's declared explicitly here so that's a
    /// guarantee, not an assumption.
    @State private var immersionStyle: any ImmersionStyle = .mixed

    var body: some Scene {
        WindowGroup {
            ContentView(session: teaSession)
        }
        .defaultSize(width: 900, height: 600)

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
