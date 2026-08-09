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

    /// Tap-the-corners is the errorless default; free tracing is the
    /// harder level a caregiver can enable.
    enum DrawMode: Equatable {
        case tapCorners
        case freeTrace
    }

    struct CornerTarget: Identifiable {
        let id: Int
        let coordinate: CLLocationCoordinate2D
        let routePointIndex: Int
    }

    private(set) var state: State = .idle
    var drawMode: DrawMode = .tapCorners
    private(set) var route: MKRoute?
    private(set) var routePoints: [CLLocationCoordinate2D] = []

    // Free-trace state.
    private(set) var drawnPath: [CLLocationCoordinate2D] = []
    private(set) var averageErrorMeters: Double?

    // Tap-corners state.
    private(set) var cornerTargets: [CornerTarget] = []
    private(set) var nextCornerIndex = 0
    private(set) var wrongOrderTaps = 0
    private(set) var lastWrongTapID: Int?

    // Invisible metrics — never shown to the patient.
    private(set) var studyStartedAt: Date?
    private(set) var studySeconds: Double?
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?

    var routeMidpoint: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (DemoRoute.start.latitude + DemoRoute.home.latitude) / 2,
            longitude: (DemoRoute.start.longitude + DemoRoute.home.longitude) / 2
        )
    }

    /// Route revealed so far in tap-corners mode: real route geometry up to
    /// the last correctly tapped corner.
    var revealedRoute: [CLLocationCoordinate2D] {
        guard nextCornerIndex > 0, !cornerTargets.isEmpty else { return [] }
        let lastIndex = cornerTargets[nextCornerIndex - 1].routePointIndex
        return Array(routePoints.prefix(through: min(lastIndex, routePoints.count - 1)))
    }

    var feedback: String {
        switch drawMode {
        case .tapCorners:
            switch wrongOrderTaps {
            case 0: return "Amazing! You remembered every corner of the way home."
            case 1...2: return "Well done — you found the way home."
            default: return "Good try! Let's look at the way together once more."
            }
        case .freeTrace:
            guard let error = averageErrorMeters else { return "" }
            switch error {
            case ..<25: return "Amazing! You remembered the whole way home."
            case ..<50: return "Well done — that's very close to the real route."
            default: return "Good try! Let's study the route once more."
            }
        }
    }

    func begin() {
        state = .loading
        drawnPath = []
        averageErrorMeters = nil
        nextCornerIndex = 0
        wrongOrderTaps = 0
        lastWrongTapID = nil
        studyStartedAt = nil
        studySeconds = nil
        startedAt = .now
        completedAt = nil
        Task { await load() }
    }

    func stop() {}

    /// Study is self-paced — no countdown, no time pressure. How long they
    /// looked is recorded invisibly.
    func startDrawing() {
        guard state == .studying else { return }
        if let studyStartedAt {
            studySeconds = Date.now.timeIntervalSince(studyStartedAt)
        }
        nextCornerIndex = 0
        drawnPath = []
        state = .drawing
    }

    func toggleDrawMode() {
        drawMode = drawMode == .tapCorners ? .freeTrace : .tapCorners
    }

    // MARK: - Free trace

    func addDrawnPoint(_ coordinate: CLLocationCoordinate2D) {
        guard state == .drawing, drawMode == .freeTrace else { return }
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
        nextCornerIndex = 0
    }

    func finishDrawing() {
        guard state == .drawing, drawMode == .freeTrace, drawnPath.count >= 2 else { return }
        averageErrorMeters = scoreTrace()
        completedAt = .now
        state = .scored
    }

    // MARK: - Tap the corners

    func tapCorner(id: Int) {
        guard state == .drawing, drawMode == .tapCorners else { return }
        guard cornerTargets.indices.contains(id) else { return }

        if id == nextCornerIndex {
            lastWrongTapID = nil
            nextCornerIndex += 1
            if nextCornerIndex >= cornerTargets.count {
                completedAt = .now
                state = .scored
            }
        } else if id > nextCornerIndex {
            // Gentle wrong-order beat, counted invisibly.
            wrongOrderTaps += 1
            lastWrongTapID = id
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                if lastWrongTapID == id {
                    lastWrongTapID = nil
                }
            }
        }
    }

    // MARK: - Loading

    private func load() async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: DemoRoute.start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: DemoRoute.home))
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                state = .failed
                return
            }
            self.route = route
            routePoints = Self.coordinates(of: route.polyline)
            cornerTargets = Self.cornerTargets(from: routePoints)
            studyStartedAt = .now
            state = .studying
        } catch {
            state = .failed
        }
    }

    /// Decision corners along the route (heading change ≥ 25°) plus home,
    /// capped so the tap task stays gentle.
    private static func cornerTargets(from points: [CLLocationCoordinate2D]) -> [CornerTarget] {
        guard points.count >= 2 else { return [] }
        var picks: [Int] = []
        var lastKept = 0
        for i in 1..<(points.count - 1) {
            let d1 = NeighborhoodWorld.enu(points[i]) - NeighborhoodWorld.enu(points[lastKept])
            let d2 = NeighborhoodWorld.enu(points[i + 1]) - NeighborhoodWorld.enu(points[i])
            guard simd_length(d1) > 8, simd_length(d2) > 3 else { continue }
            let h1 = atan2(d1.x, -d1.y) * 180 / .pi
            let h2 = atan2(d2.x, -d2.y) * 180 / .pi
            var delta = (h2 - h1).truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            if abs(delta) >= 25 {
                picks.append(i)
                lastKept = i
            }
        }
        picks.append(points.count - 1)
        let capped = picks.count > 7 ? Array(picks.prefix(6)) + [points.count - 1] : picks
        return capped.enumerated().map { order, pointIndex in
            CornerTarget(id: order, coordinate: points[pointIndex], routePointIndex: pointIndex)
        }
    }

    /// Mean distance in meters from each drawn point to the nearest segment
    /// of the real route.
    private func scoreTrace() -> Double {
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
