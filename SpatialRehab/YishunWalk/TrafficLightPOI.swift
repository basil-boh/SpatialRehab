import CoreLocation
import Foundation

struct TrafficLightPOI: Identifiable, Sendable, Equatable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    var state: TrafficLightState

    init(
        id: UUID = UUID(),
        name: String,
        coordinate: CLLocationCoordinate2D,
        state: TrafficLightState = .red
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.state = state
    }

    static func == (lhs: TrafficLightPOI, rhs: TrafficLightPOI) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.state == rhs.state
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

extension TrafficLightPOI {
    /// Curated demo crossings near the Northpoint → Blk 343 Yishun walk.
    /// Coordinates are approximate; refined when the live polyline loads.
    static let yishunDemoSeed: [TrafficLightPOI] = [
        TrafficLightPOI(
            name: "Yishun Ave 2 crossing",
            coordinate: CLLocationCoordinate2D(latitude: 1.4298, longitude: 103.8375),
            state: .red
        ),
        TrafficLightPOI(
            name: "Yishun Ave 11 approach",
            coordinate: CLLocationCoordinate2D(latitude: 1.4302, longitude: 103.8420),
            state: .green
        ),
        TrafficLightPOI(
            name: "Near Block 343",
            coordinate: CLLocationCoordinate2D(latitude: 1.4306, longitude: 103.8445),
            state: .red
        ),
    ]
}
