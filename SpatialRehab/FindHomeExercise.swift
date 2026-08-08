import Foundation
import MapKit
import Observation
import UIKit

@Observable
@MainActor
final class FindHomeExercise {
    enum Turn: CaseIterable {
        case left
        case straight
        case right
    }

    enum State: Equatable {
        case idle
        case loading
        case junction
        case arrived
        case failed
    }

    struct Junction {
        let coordinate: CLLocationCoordinate2D
        let correctTurn: Turn
        let incomingHeading: Double
        let outgoingHeading: Double
    }

    // Demo route: Tiong Bahru Market → Eng Hoon Street ("home").
    static let start = CLLocationCoordinate2D(latitude: 1.28470, longitude: 103.83266)
    static let home = CLLocationCoordinate2D(latitude: 1.28360, longitude: 103.83060)

    private(set) var state: State = .idle
    private(set) var route: MKRoute?
    private(set) var junctions: [Junction] = []
    private(set) var currentJunctionIndex = 0
    private(set) var scenes: [Int: MKLookAroundScene] = [:]
    private(set) var snapshotURLs: [Int: URL] = [:]
    private(set) var lastChoiceWrong = false
    private(set) var wrongTurns = 0
    private(set) var startedAt: Date?
    private(set) var completedAt: Date?
    private var prepareTask: Task<Void, Never>?

    var currentJunction: Junction? {
        junctions.indices.contains(currentJunctionIndex) ? junctions[currentJunctionIndex] : nil
    }

    var currentScene: MKLookAroundScene? { scenes[currentJunctionIndex] }
    var currentSnapshotURL: URL? { snapshotURLs[currentJunctionIndex] }

    /// Snapshot files in route order, for pre-generating spatial scenes.
    var orderedSnapshotURLs: [URL] {
        junctions.indices.compactMap { snapshotURLs[$0] }
    }

    /// Kick off route + imagery loading ahead of time (call at app launch) so
    /// the street is already on disk when the patient starts the activity.
    func prepare() {
        guard state == .idle || state == .failed else { return }
        state = .loading
        prepareTask?.cancel()
        prepareTask = Task { await load() }
    }

    /// Start (or restart) a play-through. Loaded route and imagery are kept.
    func begin() {
        switch state {
        case .idle, .failed:
            prepare()
        case .loading:
            break
        case .junction, .arrived:
            currentJunctionIndex = 0
            lastChoiceWrong = false
            wrongTurns = 0
            startedAt = nil
            completedAt = nil
            state = junctions.isEmpty ? .arrived : .junction
        }
    }

    func choose(_ turn: Turn) {
        guard state == .junction, let junction = currentJunction else { return }
        if startedAt == nil {
            startedAt = .now
        }
        if turn == junction.correctTurn {
            lastChoiceWrong = false
            advance()
        } else {
            lastChoiceWrong = true
            wrongTurns += 1
        }
    }

    private func advance() {
        currentJunctionIndex += 1
        if currentJunctionIndex >= junctions.count {
            state = .arrived
            completedAt = .now
        }
    }

    private func load() async {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: Self.start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: Self.home))
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                state = .failed
                return
            }
            self.route = route
            junctions = Self.junctions(for: route)
            guard !junctions.isEmpty else {
                state = .arrived
                completedAt = .now
                return
            }
            state = .junction
            // Load imagery in route order so the first junction is ready first.
            for index in junctions.indices {
                guard !Task.isCancelled else { return }
                await loadAssets(for: index)
            }
        } catch {
            state = .failed
        }
    }

    private func loadAssets(for index: Int) async {
        guard let scene = try? await MKLookAroundSceneRequest(
            coordinate: junctions[index].coordinate
        ).scene else { return }
        scenes[index] = scene

        let options = MKLookAroundSnapshotter.Options()
        options.size = CGSize(width: 1600, height: 1200)
        guard
            let snapshot = try? await MKLookAroundSnapshotter(scene: scene, options: options).snapshot,
            let data = snapshot.image.jpegData(compressionQuality: 0.9)
        else { return }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("findhome-junction-\(index).jpg")
        do {
            try data.write(to: url)
            snapshotURLs[index] = url
        } catch {
            snapshotURLs[index] = nil
        }
    }

    /// A junction is each boundary between consecutive route steps. The correct
    /// turn comes from the route geometry (heading change), not the localized
    /// instruction text, so any address works.
    private static func junctions(for route: MKRoute) -> [Junction] {
        let steps = route.steps.filter { $0.polyline.pointCount >= 2 }
        guard steps.count >= 2 else { return [] }

        var result: [Junction] = []
        for index in 0..<(steps.count - 1) {
            let incoming = coordinates(of: steps[index].polyline)
            let outgoing = coordinates(of: steps[index + 1].polyline)
            guard
                let corner = outgoing.first,
                let inHeading = bearing(alongLastLegOf: incoming),
                let outHeading = bearing(alongFirstLegOf: outgoing)
            else { continue }

            let delta = normalizedDegrees(outHeading - inHeading)
            let turn: Turn = abs(delta) < 30 ? .straight : (delta < 0 ? .left : .right)
            result.append(Junction(
                coordinate: corner,
                correctTurn: turn,
                incomingHeading: inHeading,
                outgoingHeading: outHeading
            ))
        }
        return Array(result.prefix(5))
    }

    private static func coordinates(of polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: polyline.pointCount
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords
    }

    private static func bearing(alongFirstLegOf coords: [CLLocationCoordinate2D]) -> Double? {
        guard let first = coords.first else { return nil }
        guard let next = coords.dropFirst().first(where: { distanceApprox(first, $0) > 3 }) else { return nil }
        return bearing(from: first, to: next)
    }

    private static func bearing(alongLastLegOf coords: [CLLocationCoordinate2D]) -> Double? {
        guard let last = coords.last else { return nil }
        guard let previous = coords.dropLast().reversed().first(where: { distanceApprox(last, $0) > 3 }) else { return nil }
        return bearing(from: previous, to: last)
    }

    /// Bearing in degrees, 0 = north, clockwise. Equirectangular approximation
    /// is fine at walking scale.
    private static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let dLon = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
        let dLat = b.latitude - a.latitude
        return atan2(dLon, dLat) * 180 / .pi
    }

    private static func distanceApprox(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let dLon = (b.longitude - a.longitude) * cos(a.latitude * .pi / 180)
        let dLat = b.latitude - a.latitude
        return sqrt(dLon * dLon + dLat * dLat) * 111_000
    }

    private static func normalizedDegrees(_ angle: Double) -> Double {
        var value = angle.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }
}
