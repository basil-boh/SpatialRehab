import CoreLocation
import Foundation
import MapKit

/// Fixed walking route: Northpoint City → Block 343 Yishun Ave 11.
enum YishunRoute {
    static let sourceQuery = "Northpoint City, 930 Yishun Ave 2, Singapore 769098"
    static let destinationQuery = "Block 343 Yishun Ave 11, Singapore 760343"

    /// Fallback coordinates if local search is unavailable (approx. place centers).
    static let fallbackSource = CLLocationCoordinate2D(latitude: 1.4294, longitude: 103.8359)
    static let fallbackDestination = CLLocationCoordinate2D(latitude: 1.4307, longitude: 103.8452)

    static let sourceTitle = "Northpoint City"
    static let destinationTitle = "Block 343 Yishun Ave 11"
}

enum YishunRouteError: LocalizedError {
    case placeNotFound(String)
    case directionsUnavailable
    case noRoutes

    var errorDescription: String? {
        switch self {
        case .placeNotFound(let query):
            "Could not find “\(query)” on the map."
        case .directionsUnavailable:
            "Walking directions are not available right now."
        case .noRoutes:
            "No walking route was returned for this path."
        }
    }
}

struct YishunRouteLoader: Sendable {
    func loadWalkingRoute() async throws -> MKRoute {
        let sourceItem = try await mapItem(
            for: YishunRoute.sourceQuery,
            fallback: YishunRoute.fallbackSource,
            name: YishunRoute.sourceTitle
        )
        let destinationItem = try await mapItem(
            for: YishunRoute.destinationQuery,
            fallback: YishunRoute.fallbackDestination,
            name: YishunRoute.destinationTitle
        )

        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destinationItem
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        let response: MKDirections.Response
        do {
            response = try await directions.calculate()
        } catch {
            throw YishunRouteError.directionsUnavailable
        }

        guard let route = response.routes.first else {
            throw YishunRouteError.noRoutes
        }
        return route
    }

    private func mapItem(
        for query: String,
        fallback: CLLocationCoordinate2D,
        name: String
    ) async throws -> MKMapItem {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        request.region = MKCoordinateRegion(
            center: fallback,
            latitudinalMeters: 4_000,
            longitudinalMeters: 4_000
        )

        let search = MKLocalSearch(request: request)
        if let response = try? await search.start(),
           let first = response.mapItems.first {
            if first.name == nil || first.name?.isEmpty == true {
                first.name = name
            }
            return first
        }

        let location = CLLocation(latitude: fallback.latitude, longitude: fallback.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = name
        return item
    }
}
