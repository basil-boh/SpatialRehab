import Foundation
import MapKit
import Observation
import simd

@Observable
@MainActor
final class RouteMemoryExercise {
    enum State: Equatable {
        case idle
        case loading
        case studying
        case drawing
        case scored
        case failed
    }

    static let studyDuration = 30

    private(set) var state: State = .idle
    private(set) var route: MKRoute?
    private(set) var remainingStudySeconds = RouteMemoryExercise.studyDuration
    private(set) var drawnPath: [CLLocationCoordinate2D] = []
    private(set) var averageErrorMeters: Double?
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?
    private var countdownTask: Task<Void, Never>?
    private(set) var routePoints: [CLLocationCoordinate2D] = []

    var routeMidpoint: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (FindHomeExercise.start.latitude + FindHomeExercise.home.latitude) / 2,
            longitude: (FindHomeExercise.start.longitude + FindHomeExercise.home.longitude) / 2
        )
    }

    var feedback: String {
        guard let error = averageErrorMeters else { return "" }
        switch error {
        case ..<25: return "Amazing! You remembered the whole way home."
        case ..<50: return "Well done — that's very close to the real route."
        default: return "Good try! Let's study the route once more."
        }
    }

    func begin() {
        countdownTask?.cancel()
        state = .loading
        drawnPath = []
        averageErrorMeters = nil
        remainingStudySeconds = Self.studyDuration
        startedAt = .now
        completedAt = nil
        Task { await load() }
    }

    func stop() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    func startDrawing() {
        guard state == .studying else { return }
        countdownTask?.cancel()
        state = .drawing
    }

    func addDrawnPoint(_ coordinate: CLLocationCoordinate2D) {
        guard state == .drawing else { return }
        if let last = drawnPath.last {
            let lastENU = NeighborhoodWorld.enu(last)
            let nextENU = NeighborhoodWorld.enu(coordinate)
            guard simd_distance(lastENU, nextENU) > 6 else { return }
        }
        drawnPath.append(coordinate)
    }

    func clearDrawing() {
        guard state == .drawing else { return }
        drawnPath = []
    }

    func finishDrawing() {
        guard state == .drawing, drawnPath.count >= 2 else { return }
        averageErrorMeters = score()
        completedAt = .now
        state = .scored
    }

    private func load() async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: FindHomeExercise.start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: FindHomeExercise.home))
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                state = .failed
                return
            }
            self.route = route
            routePoints = Self.coordinates(of: route.polyline)
            startStudy()
        } catch {
            state = .failed
        }
    }

    /// Pauses the study countdown (e.g. while the patient walks the
    /// life-size world) without losing remaining time.
    func pauseStudy() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    func resumeStudy() {
        guard state == .studying, countdownTask == nil else { return }
        startCountdown()
    }

    private func startStudy() {
        remainingStudySeconds = Self.studyDuration
        state = .studying
        startCountdown()
    }

    private func startCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.remainingStudySeconds -= 1
                if self.remainingStudySeconds <= 0 {
                    self.state = .drawing
                    return
                }
            }
        }
    }

    /// Mean distance in meters from each drawn point to the nearest segment
    /// of the real route.
    private func score() -> Double {
        let segments = zip(routePoints, routePoints.dropFirst()).map {
            (NeighborhoodWorld.enu($0), NeighborhoodWorld.enu($1))
        }
        guard !segments.isEmpty else { return .infinity }

        var total: Double = 0
        for coordinate in drawnPath {
            let point = NeighborhoodWorld.enu(coordinate)
            var best = Float.greatestFiniteMagnitude
            for (a, b) in segments {
                let ab = b - a
                let t = max(0, min(1, simd_dot(point - a, ab) / max(simd_length_squared(ab), 0.001)))
                best = min(best, simd_distance(point, a + ab * t))
            }
            total += Double(best)
        }
        return total / Double(drawnPath.count)
    }

    private static func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: polyline.pointCount
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }
}
