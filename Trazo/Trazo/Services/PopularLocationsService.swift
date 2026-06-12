import CoreLocation
import Foundation
import MapKit

struct PopularLocation: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String

    func asMapDestination() async throws -> MapDestination {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "\(name), \(subtitle)"
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first,
              let coordinate = item.placemark.location?.coordinate else {
            throw RouteCalculatorError.noRouteFound
        }
        return MapDestination(name: name, coordinate: coordinate)
    }
}

enum PopularLocationsService {
    static let defaults: [PopularLocation] = [
        PopularLocation(id: "galerias-mtY", name: "Galerías Monterrey", subtitle: "Monterrey, N.L."),
        PopularLocation(id: "gvo", name: "Galerías Valle Oriente", subtitle: "Monterrey, N.L."),
        PopularLocation(id: "fundidora", name: "Parque Fundidora", subtitle: "Monterrey, N.L."),
        PopularLocation(id: "garza-sada", name: "Garza Sada Plaza", subtitle: "Monterrey, N.L."),
        PopularLocation(id: "arena", name: "Arena Monterrey", subtitle: "Monterrey, N.L."),
        PopularLocation(id: "paseo-san-pedro", name: "Paseo San Pedro", subtitle: "San Pedro Garza García, N.L."),
    ]

    static func nearby(from coordinate: CLLocationCoordinate2D) async -> [PopularLocation] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "parques y centros comerciales"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 8_000,
            longitudinalMeters: 8_000
        )

        do {
            let response = try await MKLocalSearch(request: request).start()
            let mapped = response.mapItems.prefix(8).compactMap { item -> PopularLocation? in
                guard let name = item.name else { return nil }
                let subtitle = item.placemark.title ?? item.placemark.locality ?? "Cerca de ti"
                return PopularLocation(id: name, name: name, subtitle: subtitle)
            }
            return mapped.isEmpty ? defaults : Array(mapped)
        } catch {
            return defaults
        }
    }
}
