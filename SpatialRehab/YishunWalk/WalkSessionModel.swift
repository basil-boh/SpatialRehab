import CoreLocation
import Foundation
import MapKit
import Observation

/// Owns the Yishun guided walk: route, virtual progress, Look Around, traffic lights.
@MainActor
@Observable
final class WalkSessionModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    private let routeLoader: YishunRouteLoader

    var loadState: LoadState = .idle
    var route: MKRoute?
    var steps: [MKRoute.Step] = []
    var currentStepIndex: Int = 0

    /// 0...1 along the walking polyline.
    var progress: Double = 0
    var isWalking = false
    var followCamera = true

    var lookAroundScene: MKLookAroundScene?
    var isLookAroundLoading = false
    var lookAroundUnavailable = false
    var isPresentingLookAroundViewer = false

    var trafficLights: [TrafficLightPOI] = TrafficLightPOI.yishunDemoSeed
    var selectedTrafficLightID: UUID?

    private var polylineCoordinates: [CLLocationCoordinate2D] = []
    private var cumulativeDistances: [CLLocationDistance] = []
    private var totalDistance: CLLocationDistance = 0

    private var walkTask: Task<Void, Never>?
    private var signalTask: Task<Void, Never>?
    private var lookAroundTask: Task<Void, Never>?

    /// Meters advanced per auto-step while walking (calm pace).
    private let metersPerTick: CLLocationDistance = 8
    private let tickIntervalNanoseconds: UInt64 = 1_200_000_000

    init(routeLoader: YishunRouteLoader = YishunRouteLoader()) {
        self.routeLoader = routeLoader
    }

    var sourceCoordinate: CLLocationCoordinate2D {
        polylineCoordinates.first ?? YishunRoute.fallbackSource
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        polylineCoordinates.last ?? YishunRoute.fallbackDestination
    }

    var walkerCoordinate: CLLocationCoordinate2D {
        coordinate(at: progress) ?? sourceCoordinate
    }

    var currentStep: MKRoute.Step? {
        guard steps.indices.contains(currentStepIndex) else { return nil }
        return steps[currentStepIndex]
    }

    var distanceDescription: String? {
        guard let route else { return nil }
        return Self.distanceFormatter.string(from: Measurement(value: route.distance, unit: UnitLength.meters))
    }

    var travelTimeDescription: String? {
        guard let route else { return nil }
        return Self.durationFormatter.string(from: route.expectedTravelTime)
    }

    var progressDescription: String {
        let pct = Int((progress * 100).rounded())
        return "\(pct)% of the walk"
    }

    var selectedTrafficLight: TrafficLightPOI? {
        guard let selectedTrafficLightID else {
            return trafficLights.first
        }
        return trafficLights.first { $0.id == selectedTrafficLightID } ?? trafficLights.first
    }

    var activeCrossingPrompt: String {
        selectedTrafficLight?.state.crossingPrompt ?? "Follow the path"
    }

    var activeCrossingState: TrafficLightState {
        selectedTrafficLight?.state ?? .red
    }

    func loadRouteIfNeeded() async {
        switch loadState {
        case .idle, .failed:
            await loadRoute()
        case .loading, .loaded:
            return
        }
    }

    func loadRoute() async {
        walkTask?.cancel()
        isWalking = false
        loadState = .loading
        lookAroundScene = nil
        lookAroundUnavailable = false

        do {
            let loaded = try await routeLoader.loadWalkingRoute()
            route = loaded
            steps = loaded.steps.filter { !$0.instructions.isEmpty || $0.distance > 0 }
            currentStepIndex = 0
            progress = 0
            rebuildPolylineSamples(from: loaded.polyline)
            placeTrafficLightsAlongRoute()
            loadState = .loaded
            selectedTrafficLightID = trafficLights.first?.id
            startSignalCycles()
            await refreshLookAround(for: walkerCoordinate)
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func startWalking() {
        guard loadState == .loaded, !isWalking else { return }
        isWalking = true
        walkTask?.cancel()
        walkTask = Task { [weak self] in
            while let self, self.isWalking, !Task.isCancelled {
                self.advance(by: self.metersPerTick)
                if self.progress >= 1 {
                    self.isWalking = false
                    break
                }
                try? await Task.sleep(nanoseconds: self.tickIntervalNanoseconds)
            }
        }
    }

    func pauseWalking() {
        isWalking = false
        walkTask?.cancel()
        walkTask = nil
    }

    func nextStep() {
        guard loadState == .loaded else { return }
        if currentStepIndex + 1 < steps.count {
            currentStepIndex += 1
            if let step = currentStep {
                snapProgressToward(step.polyline)
            }
        } else {
            progress = 1
            pauseWalking()
        }
        Task { await refreshLookAround(for: walkerCoordinate) }
        updateNearestTrafficLightSelection()
    }

    func previousStep() {
        guard loadState == .loaded else { return }
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            if let step = currentStep {
                snapProgressToward(step.polyline)
            }
        } else {
            progress = 0
        }
        Task { await refreshLookAround(for: walkerCoordinate) }
        updateNearestTrafficLightSelection()
    }

    func selectTrafficLight(_ id: UUID) {
        selectedTrafficLightID = id
    }

    func setTrafficLightState(_ state: TrafficLightState, for id: UUID) {
        guard let index = trafficLights.firstIndex(where: { $0.id == id }) else { return }
        trafficLights[index].state = state
    }

    func refreshLookAround(for coordinate: CLLocationCoordinate2D) async {
        lookAroundTask?.cancel()
        isLookAroundLoading = true
        lookAroundUnavailable = false

        lookAroundTask = Task { [weak self] in
            guard let self else { return }
            let request = MKLookAroundSceneRequest(coordinate: coordinate)
            do {
                let scene = try await request.scene
                guard !Task.isCancelled else { return }
                if let scene {
                    self.lookAroundScene = scene
                    self.lookAroundUnavailable = false
                } else {
                    self.lookAroundScene = nil
                    self.lookAroundUnavailable = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.lookAroundScene = nil
                self.lookAroundUnavailable = true
            }
            self.isLookAroundLoading = false
        }

        await lookAroundTask?.value
    }

    func stop() {
        pauseWalking()
        signalTask?.cancel()
        signalTask = nil
        lookAroundTask?.cancel()
        lookAroundTask = nil
    }

    // MARK: - Private

    private func advance(by meters: CLLocationDistance) {
        guard totalDistance > 0 else {
            progress = 1
            return
        }
        let delta = meters / totalDistance
        progress = min(1, progress + delta)
        syncStepIndexToProgress()
        updateNearestTrafficLightSelection()

        // Refresh Look Around sparingly (~every ~40 m of progress).
        let bucket = Int((progress * totalDistance) / 40)
        if bucket != lastLookAroundBucket {
            lastLookAroundBucket = bucket
            Task { await refreshLookAround(for: walkerCoordinate) }
        }
    }

    private var lastLookAroundBucket: Int = -1

    private func rebuildPolylineSamples(from polyline: MKPolyline) {
        let count = polyline.pointCount
        var coords = Array(repeating: kCLLocationCoordinate2DInvalid, count: count)
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: count))
        polylineCoordinates = coords.filter { CLLocationCoordinate2DIsValid($0) }

        cumulativeDistances = [0]
        totalDistance = 0
        guard polylineCoordinates.count > 1 else {
            totalDistance = 0
            return
        }

        for index in 1..<polylineCoordinates.count {
            let previous = polylineCoordinates[index - 1]
            let current = polylineCoordinates[index]
            let segment = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: current.latitude, longitude: current.longitude))
            totalDistance += segment
            cumulativeDistances.append(totalDistance)
        }
    }

    private func coordinate(at progress: Double) -> CLLocationCoordinate2D? {
        guard !polylineCoordinates.isEmpty else { return nil }
        if polylineCoordinates.count == 1 || totalDistance <= 0 {
            return polylineCoordinates[0]
        }

        let clamped = min(1, max(0, progress))
        let target = clamped * totalDistance

        guard let segmentEnd = cumulativeDistances.firstIndex(where: { $0 >= target }) else {
            return polylineCoordinates.last
        }
        if segmentEnd == 0 {
            return polylineCoordinates[0]
        }

        let startDistance = cumulativeDistances[segmentEnd - 1]
        let endDistance = cumulativeDistances[segmentEnd]
        let span = max(endDistance - startDistance, 0.000_1)
        let t = (target - startDistance) / span

        let a = polylineCoordinates[segmentEnd - 1]
        let b = polylineCoordinates[segmentEnd]
        return CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    private func snapProgressToward(_ stepPolyline: MKPolyline) {
        var coords = Array(
            repeating: kCLLocationCoordinate2DInvalid,
            count: stepPolyline.pointCount
        )
        stepPolyline.getCoordinates(&coords, range: NSRange(location: 0, length: stepPolyline.pointCount))
        guard let first = coords.first(where: { CLLocationCoordinate2DIsValid($0) }) else { return }

        // Find closest sample on the main route and set progress there.
        var bestIndex = 0
        var bestDistance = CLLocationDistance.greatestFiniteMagnitude
        let target = CLLocation(latitude: first.latitude, longitude: first.longitude)
        for (index, coordinate) in polylineCoordinates.enumerated() {
            let distance = target.distance(
                from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        if totalDistance > 0 {
            progress = cumulativeDistances[bestIndex] / totalDistance
        }
    }

    private func syncStepIndexToProgress() {
        guard !steps.isEmpty, totalDistance > 0 else { return }
        let targetMeters = progress * totalDistance
        var walked: CLLocationDistance = 0
        for (index, step) in steps.enumerated() {
            walked += step.distance
            if walked >= targetMeters {
                currentStepIndex = index
                return
            }
        }
        currentStepIndex = steps.count - 1
    }

    private func placeTrafficLightsAlongRoute() {
        guard totalDistance > 0, polylineCoordinates.count >= 2 else { return }
        // Place demo lights at ~30%, ~55%, ~80% along the real polyline.
        let fractions: [Double] = [0.30, 0.55, 0.80]
        let names = ["Mid-route crossing", "Yishun Ave crossing", "Near destination"]
        var placed: [TrafficLightPOI] = []
        for (index, fraction) in fractions.enumerated() {
            guard let coordinate = coordinate(at: fraction) else { continue }
            placed.append(
                TrafficLightPOI(
                    name: names[index],
                    coordinate: coordinate,
                    state: index % 2 == 0 ? .red : .green
                )
            )
        }
        if !placed.isEmpty {
            trafficLights = placed
        }
    }

    private func updateNearestTrafficLightSelection() {
        guard !trafficLights.isEmpty else { return }
        let walker = CLLocation(latitude: walkerCoordinate.latitude, longitude: walkerCoordinate.longitude)
        let nearest = trafficLights.min { lhs, rhs in
            let left = CLLocation(latitude: lhs.coordinate.latitude, longitude: lhs.coordinate.longitude)
            let right = CLLocation(latitude: rhs.coordinate.latitude, longitude: rhs.coordinate.longitude)
            return walker.distance(from: left) < walker.distance(from: right)
        }
        if let nearest {
            selectedTrafficLightID = nearest.id
        }
    }

    private func startSignalCycles() {
        signalTask?.cancel()
        signalTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                // Advance each light on its own dwell; simple sequential tick.
                for index in self.trafficLights.indices {
                    guard !Task.isCancelled else { return }
                    let dwell = self.trafficLights[index].state.dwellSeconds
                    try? await Task.sleep(nanoseconds: UInt64(dwell * 1_000_000_000))
                    guard !Task.isCancelled else { return }
                    let next = self.trafficLights[index].state.next
                    self.trafficLights[index].state = next
                }
            }
        }
    }

    private static let distanceFormatter: MeasurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.unitStyle = .medium
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter
    }()
}
