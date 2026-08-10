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
        // The shared space routes on this — without it, "way home" after a kopi or
        // mahjong session would reopen that activity instead.
        currentActivity = .routeMemory
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

/// How each activity presents itself on the home screen.
///
/// Lives beside the enum rather than inside `ContentView` for the same reason
/// `PracticeGameKind` carries its own `title`/`iconName`/`tint`: the home screen, the
/// in-activity guidance panel, and the finished screen all name the same activity, and
/// they must not drift apart.
extension AppModel.ActivityKind {
    var title: String {
        switch self {
        case .routeMemory: "Remember the Way"
        case .coffee: "Make a Cup of Kopi"
        case .mahjong: "Play Mahjong"
        }
    }

    var chineseTitle: String {
        switch self {
        case .routeMemory: "记路回家"
        case .coffee: "泡杯咖啡"
        case .mahjong: "打麻将"
        }
    }

    var symbolName: String {
        switch self {
        case .routeMemory: "map.fill"
        case .coffee: "cup.and.saucer.fill"
        case .mahjong: "square.grid.3x3.fill"
        }
    }

    /// One line describing what actually happens, shown on the "Today" card. Deliberately
    /// free of any claim about what she did or remembers — see the note on
    /// `ContentView.todayCard`.
    var blurb: String {
        switch self {
        case .routeMemory: "Walk home from the market. About six minutes."
        case .coffee: "Kopi-O, one spoon of sugar. About five minutes."
        case .mahjong: "A quiet game at the table. About eight minutes."
        }
    }

    /// The badge behind the activity's symbol — a stand-in for the scene renders Aditya's
    /// 3D work will eventually supply, keyed to each activity's actual palette (the
    /// kopitiam browns, the street's cool slate, the table's green felt).
    var badgeColors: [Color] {
        switch self {
        case .routeMemory:
            [Color(red: 0.36, green: 0.47, blue: 0.55), Color(red: 0.16, green: 0.22, blue: 0.28)]
        case .coffee:
            [Color(red: 0.62, green: 0.44, blue: 0.26), Color(red: 0.33, green: 0.20, blue: 0.11)]
        case .mahjong:
            [Color(red: 0.20, green: 0.44, blue: 0.34), Color(red: 0.09, green: 0.22, blue: 0.17)]
        }
    }

    /// Said on the finished screen. Names the thing she made rather than grading the
    /// attempt — specific praise reinforces the episodic memory the exercise was training,
    /// where a generic "well done" reinforces nothing.
    func completionLine(name: String) -> String {
        switch self {
        case .routeMemory: "You found your way home, \(name)."
        case .coffee: "That's your kopi, \(name)."
        case .mahjong: "Good game, \(name)."
        }
    }

    func completionLineChinese(name: String) -> String {
        switch self {
        case .routeMemory: "\(name)，您找到回家的路了。"
        case .coffee: "\(name)，您的咖啡泡好了。"
        case .mahjong: "\(name)，打得好。"
        }
    }
}
