import CoreLocation
import Foundation
import MapKit

enum RouteCalculatorError: LocalizedError {
    case missingUserLocation
    case noRouteFound

    var errorDescription: String? {
        switch self {
        case .missingUserLocation: "No pudimos obtener tu ubicación."
        case .noRouteFound: "No se encontró una ruta caminable hasta ese punto."
        }
    }
}

enum RouteCalculator {
    static func calculate(
        to destination: MapDestination,
        from userCoordinate: CLLocationCoordinate2D,
        profile: UserProfile?
    ) async throws -> RoutePlan {
        let request = MKDirections.Request()
        request.source = MKMapItem(
            placemark: MKPlacemark(coordinate: userCoordinate)
        )
        request.destination = MKMapItem(
            placemark: MKPlacemark(coordinate: destination.coordinate)
        )
        request.transportType = .walking

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw RouteCalculatorError.noRouteFound
        }

        return RoutePlan.build(from: route, destination: destination, profile: profile)
    }
}
