import CoreLocation
import Foundation
import MapKit
import SwiftData

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
    let gananciaElevacionM: Int
    var aiRazon: String?

    var desnivel: String {
        switch gananciaElevacionM {
        case ..<50: "Plana"
        case 50..<150: "Moderada"
        default: "Exigente"
        }
    }

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
        averagePace: String,
        gananciaElevacionM: Int = 0
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
        self.gananciaElevacionM = gananciaElevacionM
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
        profile: UserProfile?,
        gananciaElevacionM: Int = 0
    ) -> RoutePlan {
        build(
            puntos: route.polyline.coordinates,
            distanceKm: route.distance / 1000,
            destinationName: destination.name,
            destination: destination.coordinate,
            profile: profile,
            gananciaElevacionM: gananciaElevacionM
        )
    }

    static func build(
        puntos: [CLLocationCoordinate2D],
        distanceKm: Double,
        destinationName: String,
        destination: CLLocationCoordinate2D,
        profile: UserProfile?,
        gananciaElevacionM: Int = 0
    ) -> RoutePlan {
        let weight = profile?.weightKg ?? 70
        let basePace = profile?.averagePaceMinPerKm ?? 6.5

        // Penalización de ritmo y calorías por desnivel
        let gradeRatio = Double(gananciaElevacionM) / max(distanceKm * 1000, 1)
        let pacePenaltyMinPerKm = gradeRatio * 25.0      // ~+25 seg/km por cada 1% de pendiente media
        let elevFactor = 1.0 + gradeRatio * 2.0          // ~+8% calorías por 4% de pendiente media

        let adjustedPace = basePace + pacePenaltyMinPerKm
        let minutes = max(1, Int((distanceKm * adjustedPace).rounded()))
        let calories = max(1, Int((distanceKm * weight * 1.036 * elevFactor).rounded()))

        return RoutePlan(
            destinationName: destinationName,
            destination: destination,
            routePoints: puntos,
            distanceKm: distanceKm,
            estimatedMinutes: minutes,
            estimatedCalories: calories,
            averagePace: profile?.formattedPace ?? "6:30 /km",
            gananciaElevacionM: gananciaElevacionM
        )
    }
}

extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
