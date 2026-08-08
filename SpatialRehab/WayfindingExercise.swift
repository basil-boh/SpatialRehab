import Foundation
import Observation

@Observable
@MainActor
final class WayfindingExercise {
    enum LightState {
        case red
        case green
    }

    enum TapResult {
        case walk
        case blockedRed
        case ignore
    }

    static let waypointCount = 3
    /// Index of the waypoint on the far side of the road — only reachable on green.
    static let crossingWaypointIndex = 1
    static let lightInterval: Duration = .seconds(5)

    private(set) var lightState: LightState = .red
    private(set) var nextWaypoint = 0
    private(set) var redTapCount = 0
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?
    private var lightTask: Task<Void, Never>?

    var isFinished: Bool { nextWaypoint >= Self.waypointCount }

    func begin() {
        nextWaypoint = 0
        redTapCount = 0
        startedAt = .now
        completedAt = nil
        lightState = .red
        lightTask?.cancel()
        lightTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.lightInterval)
                guard let self, !Task.isCancelled else { return }
                self.lightState = self.lightState == .red ? .green : .red
            }
        }
    }

    func stop() {
        lightTask?.cancel()
        lightTask = nil
    }

    func tappedWaypoint(_ index: Int) -> TapResult {
        guard index == nextWaypoint, !isFinished else { return .ignore }
        if index == Self.crossingWaypointIndex, lightState == .red {
            redTapCount += 1
            return .blockedRed
        }
        return .walk
    }

    func arrived(at index: Int) {
        guard index == nextWaypoint else { return }
        nextWaypoint += 1
        if isFinished {
            completedAt = .now
            stop()
        }
    }
}
