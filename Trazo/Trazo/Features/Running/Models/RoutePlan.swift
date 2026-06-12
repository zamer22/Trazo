import CoreLocation
import Foundation
import MapKit

struct MapDestination: Equatable {
    var name: String
    var coordinate: CLLocationCoordinate2D

    static func == (lhs: MapDestination, rhs: MapDestination) -> Bool {
        lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct RoutePlan: Hashable, Identifiable {
    let id: UUID
    let destinationName: String
    let destinationLatitude: Double
    let destinationLongitude: Double
    let routePoints: [GeoPoint]
    let distanceKm: Double
    let estimatedMinutes: Int
    let estimatedCalories: Int
    let averagePace: String

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
    }

    var coordinates: [CLLocationCoordinate2D] {
        routePoints.map(\.coordinate)
    }

    init(
        id: UUID = UUID(),
        destinationName: String,
        destination: CLLocationCoordinate2D,
        routePoints: [CLLocationCoordinate2D],
        distanceKm: Double,
        estimatedMinutes: Int,
        estimatedCalories: Int,
        averagePace: String
    ) {
        self.id = id
        self.destinationName = destinationName
        self.destinationLatitude = destination.latitude
        self.destinationLongitude = destination.longitude
        self.routePoints = routePoints.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
        self.distanceKm = distanceKm
        self.estimatedMinutes = estimatedMinutes
        self.estimatedCalories = estimatedCalories
        self.averagePace = averagePace
    }
}

struct GeoPoint: Hashable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension RoutePlan {
    static func build(
        from route: MKRoute,
        destination: MapDestination,
        profile: UserProfile?
    ) -> RoutePlan {
        let points = route.polyline.coordinates
        let distanceKm = route.distance / 1000
        let pace = profile?.averagePaceMinPerKm ?? 6.5
        let minutes = max(1, Int((distanceKm * pace).rounded()))
        let weight = profile?.weightKg ?? 70
        let calories = max(1, Int((distanceKm * weight * 1.036).rounded()))

        return RoutePlan(
            destinationName: destination.name,
            destination: destination.coordinate,
            routePoints: points,
            distanceKm: distanceKm,
            estimatedMinutes: minutes,
            estimatedCalories: calories,
            averagePace: profile?.formattedPace ?? "6:30 /km"
        )
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
