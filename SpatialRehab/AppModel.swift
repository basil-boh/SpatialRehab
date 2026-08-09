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
        case routeMemory
        case coffee
        case mahjong
    }

    static let activitySpaceID = "ActivitySpace"

    var phase: SessionPhase = .welcome
    var currentActivity: ActivityKind = .routeMemory
    /// "Step inside" flips the shared space to full immersion.
    var routeMemoryInside = false
    let routeMemory = RouteMemoryExercise()
    let coffee = CoffeeExercise()
    let mahjong = MahjongExercise()
    let voice = VoiceGuide()
}
