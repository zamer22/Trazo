import CoreLocation
import Foundation
import Supabase

@MainActor
enum PinAdvertenciaService {
    private static let tabla = "pines_advertencia"

    static func fetchActivos(
        cerca coordenada: CLLocationCoordinate2D,
        radioKm: Double = 3.0
    ) async throws -> [PinAdvertencia] {
        let delta = radioKm / 111.0
        let latMin = coordenada.latitude  - delta
        let latMax = coordenada.latitude  + delta
        let lonMin = coordenada.longitude - delta
        let lonMax = coordenada.longitude + delta

        return try await SupabaseService.client
            .from(tabla)
            .select()
            .gte("latitud",   value: latMin)
            .lte("latitud",   value: latMax)
            .gte("longitud",  value: lonMin)
            .lte("longitud",  value: lonMax)
            .execute()
            .value
    }

    static func reportar(
        tipo: String,
        coordenada: CLLocationCoordinate2D,
        userId: UUID
    ) async throws {
        struct NuevoPin: Encodable {
            let userId: UUID
            let latitud: Double
            let longitud: Double
            let tipo: String
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case latitud, longitud, tipo
            }
        }
        try await SupabaseService.client
            .from(tabla)
            .insert(NuevoPin(userId: userId, latitud: coordenada.latitude, longitud: coordenada.longitude, tipo: tipo))
            .execute()
    }

    static func votarResuelto(pinId: UUID) async throws {
        try await SupabaseService.client
            .rpc("votar_pin_resuelto", params: ["pin_id": pinId.uuidString])
            .execute()
    }
}
