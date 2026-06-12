import CoreLocation
import Foundation
import SwiftUI

struct PinAdvertencia: Identifiable, Codable, Sendable {
    let id: UUID
    let userId: UUID
    let latitud: Double
    let longitud: Double
    let tipo: String
    let creadoEn: Date
    let votosResuelto: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitud, longitude: longitud)
    }

    var icono: String {
        switch tipo {
        case "bache":     return "exclamationmark.triangle.fill"
        case "basura":    return "trash.fill"
        case "inundacion": return "drop.fill"
        case "obra":      return "hammer.fill"
        case "obstaculo": return "xmark.octagon.fill"
        default:          return "exclamationmark.shield.fill"
        }
    }

    var colorFondo: Color {
        switch tipo {
        case "inundacion": return .blue
        case "obra":       return .orange
        case "basura":     return Color(hex: 0x7A7A7A)
        default:           return .red
        }
    }

    var etiqueta: String {
        switch tipo {
        case "bache":      return "Bache"
        case "basura":     return "Basura"
        case "inundacion": return "Inundado"
        case "obra":       return "Obra"
        case "obstaculo":  return "Obstáculo"
        default:           return "Peligro"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case userId     = "user_id"
        case latitud
        case longitud
        case tipo
        case creadoEn   = "creado_en"
        case votosResuelto = "votos_resuelto"
    }
}

private extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}
