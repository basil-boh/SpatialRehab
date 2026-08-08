import Foundation
import Observation

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
}
