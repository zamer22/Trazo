import CoreLocation
import Foundation
import Supabase

@MainActor
enum RestaurantesService {
    static func fetchCercanos(lat: Double, lon: Double, radioKm: Double = 3.0) async throws -> [Restaurante] {
        let delta = radioKm / 111.0
        let restaurantes: [Restaurante] = try await SupabaseService.client
            .from("restaurantes")
            .select()
            .gte("latitud", value: lat - delta)
            .lte("latitud", value: lat + delta)
            .gte("longitud", value: lon - delta)
            .lte("longitud", value: lon + delta)
            .execute()
            .value
        return restaurantes
    }

    static func buscar(texto: String) async throws -> [Restaurante] {
        let restaurantes: [Restaurante] = try await SupabaseService.client
            .from("restaurantes")
            .select()
            .ilike("nombre", pattern: "%\(texto)%")
            .limit(20)
            .execute()
            .value
        return restaurantes
    }

    static func calificar(restauranteId: UUID, userId: UUID, rating: Int) async throws {
        try await SupabaseService.client
            .from("calificaciones_restaurante")
            .upsert([
                "restaurante_id": restauranteId.uuidString,
                "user_id": userId.uuidString,
                "rating": "\(rating)"
            ])
            .execute()
    }

    static func miCalificacion(restauranteId: UUID, userId: UUID) async -> Int? {
        let response = try? await SupabaseService.client
            .from("calificaciones_restaurante")
            .select("rating")
            .eq("restaurante_id", value: restauranteId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
        guard let data = response?.data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let r = json["rating"] as? Int else { return nil }
        return r
    }
}
