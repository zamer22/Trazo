import CoreLocation
import Foundation
import SwiftUI

struct Restaurante: Identifiable, Codable {
    let id: UUID
    let nombre: String
    let descripcion: String?
    let tipo: String
    let latitud: Double
    let longitud: Double
    var ratingPromedio: Double
    var totalCalificaciones: Int
    let fotoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, descripcion, tipo, latitud, longitud
        case ratingPromedio = "rating_promedio"
        case totalCalificaciones = "total_calificaciones"
        case fotoUrl = "foto_url"
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitud, longitude: longitud)
    }

    func distanciaDesde(_ coord: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: latitud, longitude: longitud)
            .distance(from: CLLocation(latitude: coord.latitude, longitude: coord.longitude))
    }

    func distanciaFormateada(desde coord: CLLocationCoordinate2D) -> String {
        let metros = distanciaDesde(coord)
        if metros < 1000 { return "\(Int(metros)) m" }
        return String(format: "%.1f km", metros / 1000)
    }

    var icono: String {
        switch tipo {
        case "cafe":       return "cup.and.saucer.fill"
        case "panaderia":  return "birthday.cake.fill"
        case "saludable":  return "leaf.fill"
        case "bar":        return "wineglass.fill"
        default:           return "fork.knife"
        }
    }

    var colorTipo: Color {
        switch tipo {
        case "cafe":       return .brown
        case "saludable":  return .green
        case "panaderia":  return .orange
        default:           return TrazoColors.routeTeal
        }
    }
}
