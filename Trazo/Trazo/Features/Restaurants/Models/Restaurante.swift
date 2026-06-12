import CoreLocation
import Foundation
import SwiftUI

struct Restaurante: Identifiable, Codable, Hashable {
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
        case "cafe":            return "cup.and.saucer.fill"
        case "panaderia":       return "birthday.cake.fill"
        case "saludable":       return "leaf.fill"
        case "bar":             return "wineglass.fill"
        case "tacos":           return "fork.knife.circle.fill"
        case "pizzeria":        return "flame.fill"
        case "hamburgueseria":  return "takeoutbag.and.cup.and.straw.fill"
        case "helados":         return "snowflake"
        default:                return "fork.knife"
        }
    }

    var colorTipo: Color {
        switch tipo {
        case "cafe":            return .brown
        case "saludable":       return .green
        case "panaderia":       return .orange
        case "bar":             return .purple
        case "tacos":           return Color(red: 0.9, green: 0.4, blue: 0.1)
        case "pizzeria":        return .red
        case "hamburgueseria":  return Color(red: 0.7, green: 0.5, blue: 0.1)
        case "helados":         return .cyan
        default:                return TrazoColors.routeTeal
        }
    }

    var etiquetaTipo: String {
        switch tipo {
        case "cafe":            return "Café"
        case "panaderia":       return "Panadería"
        case "saludable":       return "Saludable"
        case "bar":             return "Bar"
        case "tacos":           return "Tacos"
        case "pizzeria":        return "Pizzería"
        case "hamburgueseria":  return "Hamburguesas"
        case "helados":         return "Helados"
        case "restaurante":     return "Restaurante"
        default:                return tipo.capitalized
        }
    }
}

struct CuponRestaurante: Identifiable, Codable, Hashable {
    let id: UUID
    let restauranteId: UUID
    let titulo: String
    let descripcion: String?
    let codigo: String
    let descuentoPorcentaje: Int?
    let visitasRequeridas: Int

    enum CodingKeys: String, CodingKey {
        case id, titulo, descripcion, codigo
        case restauranteId = "restaurante_id"
        case descuentoPorcentaje = "descuento_porcentaje"
        case visitasRequeridas = "visitas_requeridas"
    }
}

struct CuponUsuario: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let cuponId: UUID
    let desbloqueadoEn: Date
    let canjeadoEn: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cuponId = "cupon_id"
        case desbloqueadoEn = "desbloqueado_en"
        case canjeadoEn = "canjeado_en"
    }
}

struct VisitaRestaurante: Identifiable, Codable, Hashable {
    let id: UUID
    let userId: UUID
    let restauranteId: UUID
    let visitadoEn: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case restauranteId = "restaurante_id"
        case visitadoEn = "visitado_en"
    }
}

struct CuponConRestaurante: Identifiable, Hashable {
    let cupon: CuponRestaurante
    let restaurante: Restaurante
    let canjeado: Bool

    var id: UUID { cupon.id }
}
