import CoreLocation
import Foundation
import Supabase

@MainActor
enum RestaurantesService {
    static func fetchCercanos(lat: Double, lon: Double, radioKm: Double = 5.0) async throws -> [Restaurante] {
        let delta = radioKm / 111.0
        let cercanos: [Restaurante] = try await SupabaseService.client
            .from("restaurantes")
            .select()
            .gte("latitud", value: lat - delta)
            .lte("latitud", value: lat + delta)
            .gte("longitud", value: lon - delta)
            .lte("longitud", value: lon + delta)
            .execute()
            .value

        // Fallback: si no hay nada cerca, traer todos (UX mejor que pantalla vacía)
        if cercanos.isEmpty {
            return try await fetchTodos()
        }
        return cercanos
    }

    static func fetchTodos(limit: Int = 50) async throws -> [Restaurante] {
        let todos: [Restaurante] = try await SupabaseService.client
            .from("restaurantes")
            .select()
            .limit(limit)
            .execute()
            .value
        return todos
    }

    static func fetchRecomendados(lat: Double, lon: Double) async throws -> [Restaurante] {
        // Mejor calificados primero; si no hay calificaciones, ordena por proximidad calculada en cliente
        let todos = try await fetchCercanos(lat: lat, lon: lon, radioKm: 10.0)
        return todos.sorted { a, b in
            if a.totalCalificaciones != b.totalCalificaciones {
                return a.totalCalificaciones > b.totalCalificaciones
            }
            if a.ratingPromedio != b.ratingPromedio {
                return a.ratingPromedio > b.ratingPromedio
            }
            let origen = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            return a.distanciaDesde(origen) < b.distanciaDesde(origen)
        }
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

    // MARK: - Cupones / Visitas

    struct VisitaResultado: Decodable {
        let totalVisitas: Int
        let cuponesDesbloqueados: [CuponDesbloqueado]

        enum CodingKeys: String, CodingKey {
            case totalVisitas = "total_visitas"
            case cuponesDesbloqueados = "cupones_desbloqueados"
        }
    }

    struct CuponDesbloqueado: Decodable, Hashable {
        let id: UUID
        let titulo: String
        let codigo: String
        let descuentoPorcentaje: Int?

        enum CodingKeys: String, CodingKey {
            case id, titulo, codigo
            case descuentoPorcentaje = "descuento_porcentaje"
        }
    }

    static func registrarVisita(restauranteId: UUID) async throws -> VisitaResultado {
        struct Params: Encodable { let p_restaurante_id: UUID }
        let resp = try await SupabaseService.client
            .rpc("registrar_visita_restaurante", params: Params(p_restaurante_id: restauranteId))
            .execute()
        let decoder = JSONDecoder()
        return try decoder.decode(VisitaResultado.self, from: resp.data)
    }

    static func totalVisitas(restauranteId: UUID, userId: UUID) async -> Int {
        let visitas: [VisitaRestaurante] = (try? await SupabaseService.client
            .from("visitas_restaurante")
            .select()
            .eq("restaurante_id", value: restauranteId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
            .value) ?? []
        return visitas.count
    }

    static func cuponesDelRestaurante(restauranteId: UUID) async throws -> [CuponRestaurante] {
        let cupones: [CuponRestaurante] = try await SupabaseService.client
            .from("cupones_restaurante")
            .select()
            .eq("restaurante_id", value: restauranteId.uuidString)
            .eq("activo", value: true)
            .order("visitas_requeridas", ascending: true)
            .execute()
            .value
        return cupones
    }

    static func cuponesDesbloqueadosPorUsuario(userId: UUID) async throws -> [CuponUsuario] {
        let cupones: [CuponUsuario] = try await SupabaseService.client
            .from("cupones_usuario")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("desbloqueado_en", ascending: false)
            .execute()
            .value
        return cupones
    }

    static func cuponesConRestaurante(userId: UUID) async throws -> [CuponConRestaurante] {
        let userCupones = try await cuponesDesbloqueadosPorUsuario(userId: userId)
        guard !userCupones.isEmpty else { return [] }

        let cuponIds = userCupones.map(\.cuponId.uuidString)
        let cupones: [CuponRestaurante] = try await SupabaseService.client
            .from("cupones_restaurante")
            .select()
            .in("id", values: cuponIds)
            .execute()
            .value

        let restIds = Array(Set(cupones.map(\.restauranteId.uuidString)))
        let restaurantes: [Restaurante] = try await SupabaseService.client
            .from("restaurantes")
            .select()
            .in("id", values: restIds)
            .execute()
            .value

        let restMap = Dictionary(uniqueKeysWithValues: restaurantes.map { ($0.id, $0) })
        let canjeMap = Dictionary(uniqueKeysWithValues: userCupones.map { ($0.cuponId, $0.canjeadoEn != nil) })

        return cupones.compactMap { c -> CuponConRestaurante? in
            guard let r = restMap[c.restauranteId] else { return nil }
            return CuponConRestaurante(cupon: c, restaurante: r, canjeado: canjeMap[c.id] ?? false)
        }
    }

    static func visitasDelUsuario(userId: UUID) async throws -> [Restaurante] {
        let visitas: [VisitaRestaurante] = try await SupabaseService.client
            .from("visitas_restaurante")
            .select()
            .eq("user_id", value: userId.uuidString)
            .order("visitado_en", ascending: false)
            .execute()
            .value

        let restIds = Array(Set(visitas.map(\.restauranteId.uuidString)))
        guard !restIds.isEmpty else { return [] }

        let restaurantes: [Restaurante] = try await SupabaseService.client
            .from("restaurantes")
            .select()
            .in("id", values: restIds)
            .execute()
            .value
        return restaurantes
    }
}
