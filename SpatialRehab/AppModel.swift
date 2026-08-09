import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AppModel {
    enum SessionPhase {
        case welcome
        case openingActivity
        case inActivity
        case finished
    }

    static let activitySpaceID = "ActivitySpace"

    var phase: SessionPhase = .welcome
    /// "Step inside" flips the shared space to full immersion.
    var routeMemoryInside = false
    let routeMemory = RouteMemoryExercise()
    let voice = VoiceGuide()

    /// Starts the Remember the Way activity: begins the exercise, opens the shared
    /// immersive space, and dismisses the main window on success (the space's own control
    /// panel is the only guidance surface during the activity; `RouteMemoryTableView.
    /// onDisappear` reopens the window when the activity ends). Lives here because two
    /// controls trigger the same surface — the home screen's Start/Play again buttons and
    /// the name card's "Show me the way home". No-op while the activity is already
    /// opening or open, so the card's button can't double-launch it.
    func startWayHome(
        openImmersiveSpace: OpenImmersiveSpaceAction,
        dismissWindow: DismissWindowAction
    ) async {
        guard phase != .openingActivity, phase != .inActivity else { return }
        phase = .openingActivity
        routeMemory.begin()
        switch await openImmersiveSpace(id: Self.activitySpaceID) {
        case .opened:
            phase = .inActivity
            dismissWindow(id: SceneID.main)
        case .userCancelled, .error:
            phase = .welcome
        @unknown default:
            phase = .welcome
        }
    }
}
