import CoreLocation
import Foundation
import MapKit

enum RouteCalculatorError: LocalizedError {
    case missingUserLocation
    case noRouteFound

    var errorDescription: String? {
        switch self {
        case .missingUserLocation: "No pudimos obtener tu ubicación."
        case .noRouteFound: "No se encontró un Trazo caminable en esa zona."
        }
    }
}

enum RouteCalculator {

    // Ruta hacia un destino específico
    static func calculate(
        to destination: MapDestination,
        from userCoordinate: CLLocationCoordinate2D,
        profile: UserProfile?
    ) async throws -> RoutePlan {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userCoordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination.coordinate))
        request.transportType = .walking

        let response = try await MKDirections(request: request).calculate()
        guard let route = response.routes.first else {
            throw RouteCalculatorError.noRouteFound
        }

        let puntos = route.polyline.coordinates
        let ganancia = await ElevacionService.calcularGanancia(coordenadas: puntos)
        return RoutePlan.build(from: route, destination: destination, profile: profile, gananciaElevacionM: ganancia)
    }

    // Ruta circular: sale y regresa al mismo punto
    // Usa corrección iterativa de distancia para que el resultado se aproxime al target.
    static func calculateCircular(
        distanciaKm: Double,
        from origin: CLLocationCoordinate2D,
        profile: UserProfile?
    ) async throws -> RoutePlan {
        // Factor inicial conservador. Monterrey tiene cuadrícula con ratio ~1.6–1.7
        // waypointKm = distanciaKm / (2 * 1.65) ≈ distanciaKm * 0.30
        let factorInicial = 0.30
        let tolerancia = 0.12   // ±12% aceptable
        let bearings: [Double] = [0, 45, 90, 135, 180, 225, 270, 315].shuffled()

        for bearing in bearings {
            var waypointKm = distanciaKm * factorInicial

            for intento in 0...1 {
                let waypoint = desplazar(origen: origin, km: waypointKm, grados: bearing)

                let r1 = MKDirections.Request()
                r1.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
                r1.destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoint))
                r1.transportType = .walking

                let r2 = MKDirections.Request()
                r2.source = MKMapItem(placemark: MKPlacemark(coordinate: waypoint))
                r2.destination = MKMapItem(placemark: MKPlacemark(coordinate: origin))
                r2.transportType = .walking

                do {
                    async let resp1 = MKDirections(request: r1).calculate()
                    async let resp2 = MKDirections(request: r2).calculate()
                    let (a, b) = try await (resp1, resp2)
                    guard let seg1 = a.routes.first, let seg2 = b.routes.first else { break }

                    let totalKm = (seg1.distance + seg2.distance) / 1_000
                    let ratio = distanciaKm / totalKm
                    let error = abs(1.0 - ratio)

                    if error <= tolerancia || intento == 1 {
                        // Dentro de tolerancia, o segundo intento — usar este resultado
                        let puntos = seg1.polyline.coordinates + seg2.polyline.coordinates
                        let ganancia = await ElevacionService.calcularGanancia(coordenadas: puntos)
                        return RoutePlan.build(
                            puntos: puntos,
                            distanceKm: totalKm,
                            destinationName: "Trazo circular",
                            destination: origin,
                            profile: profile,
                            gananciaElevacionM: ganancia
                        )
                    }
                    // Primer intento fuera de tolerancia — corregir el factor
                    waypointKm *= ratio
                } catch {
                    break
                }
            }
        }
        throw RouteCalculatorError.noRouteFound
    }

    // Desplaza un punto desde un origen a una distancia y rumbo dados
    private static func desplazar(
        origen: CLLocationCoordinate2D,
        km: Double,
        grados: Double
    ) -> CLLocationCoordinate2D {
        let R = 6_371.0
        let d = km / R
        let b = grados * .pi / 180
        let lat1 = origen.latitude * .pi / 180
        let lon1 = origen.longitude * .pi / 180
        let lat2 = asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(b))
        let dLon = atan2(sin(b) * sin(d) * cos(lat1), cos(d) - sin(lat1) * sin(lat2))
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: (lon1 + dLon) * 180 / .pi
        )
    }
}
