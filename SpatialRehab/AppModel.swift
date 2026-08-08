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

    enum ActivityKind {
        case touchTheDots
        case wayfinding
        case findHome
        case routeMemory
    }

    static let activitySpaceID = "ActivitySpace"

    var phase: SessionPhase = .welcome
    var currentActivity: ActivityKind = .touchTheDots
    /// Route-memory "step inside" flips the shared space to full immersion.
    var routeMemoryInside = false
    let dotsGame = TouchTheDotsGame()
    let wayfinding = WayfindingExercise()
    let findHome = FindHomeExercise()
    let routeMemory = RouteMemoryExercise()
}
