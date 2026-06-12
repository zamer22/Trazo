import Foundation
import Supabase

@MainActor
@Observable
final class ClubService {
    var misClubs: [Club] = []
    var mensajes: [ClubMensaje] = []
    var sesionActiva: SesionClub?
    var rutasPropuestas: [RutaPropuesta] = []
    var miVotoId: UUID?
    var cargando = false
    var error: String?

    private var pollingTask: Task<Void, Never>?

    // MARK: - Clubs

    func cargarMisClubs(userId: UUID) async {
        cargando = true
        defer { cargando = false }
        do {
            struct IdRow: Decodable { let club_id: UUID }
            let ids: [IdRow] = try await SupabaseService.client
                .from("club_miembros").select("club_id")
                .eq("user_id", value: userId.uuidString)
                .execute().value
            let clubIds = ids.map { $0.club_id.uuidString }
            guard !clubIds.isEmpty else { misClubs = []; return }
            misClubs = try await SupabaseService.client
                .from("clubs").select().in("id", values: clubIds).execute().value
        } catch { self.error = "Error cargando clubs" }
    }

    func clubsPublicos(busqueda: String = "") async throws -> [Club] {
        var query = SupabaseService.client
            .from("clubs")
            .select()
            .eq("es_publico", value: true)
        if !busqueda.isEmpty {
            query = query.ilike("nombre", pattern: "%\(busqueda)%")
        }
        return try await query.limit(30).execute().value
    }

    func crearClub(nombre: String, descripcion: String?, esPublico: Bool, userId: UUID) async throws -> Club {
        struct NuevoClub: Encodable {
            let nombre: String; let descripcion: String; let codigo: String
            let es_publico: Bool; let creado_por: UUID
        }
        let club: Club = try await SupabaseService.client
            .from("clubs")
            .insert(NuevoClub(nombre: nombre, descripcion: descripcion ?? "", codigo: generarCodigo(), es_publico: esPublico, creado_por: userId))
            .select().single().execute().value
        try await unirseAClub(clubId: club.id, userId: userId, rol: "admin")
        misClubs.append(club)
        return club
    }

    func unirseConCodigo(codigo: String, userId: UUID) async throws -> Club {
        let club: Club = try await SupabaseService.client
            .from("clubs").select().eq("codigo", value: codigo.uppercased()).single().execute().value
        try await unirseAClub(clubId: club.id, userId: userId, rol: "miembro")
        if !misClubs.contains(where: { $0.id == club.id }) { misClubs.append(club) }
        return club
    }

    private func unirseAClub(clubId: UUID, userId: UUID, rol: String) async throws {
        struct Miembro: Encodable { let club_id: UUID; let user_id: UUID; let rol: String }
        try await SupabaseService.client
            .from("club_miembros").upsert(Miembro(club_id: clubId, user_id: userId, rol: rol)).execute()
    }

    // MARK: - Chat

    func cargarMensajes(clubId: UUID) async {
        let result: [ClubMensaje]? = try? await SupabaseService.client
            .from("club_mensajes").select()
            .eq("club_id", value: clubId.uuidString)
            .order("creado_en", ascending: true)
            .limit(100).execute().value
        mensajes = result ?? []
    }

    func enviarMensaje(clubId: UUID, userId: UUID, nombreUsuario: String, contenido: String) async throws {
        struct NuevoMsg: Encodable { let club_id: UUID; let user_id: UUID; let nombre_usuario: String; let contenido: String }
        try await SupabaseService.client
            .from("club_mensajes")
            .insert(NuevoMsg(club_id: clubId, user_id: userId, nombre_usuario: nombreUsuario, contenido: contenido))
            .execute()
    }

    func iniciarPollingMensajes(clubId: UUID) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { break }
                await self.cargarMensajes(clubId: clubId)
            }
        }
    }

    func iniciarPollingSesion(clubId: UUID) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard let self, !Task.isCancelled else { break }
                await self.cargarSesionActiva(clubId: clubId)
            }
        }
    }

    func detenerPolling() { pollingTask?.cancel() }

    // MARK: - Sesión Mario Kart

    func crearSesion(clubId: UUID, modo: String, userId: UUID) async throws -> SesionClub {
        struct NuevaSesion: Encodable { let club_id: UUID; let modo: String; let creado_por: UUID }
        let sesion: SesionClub = try await SupabaseService.client
            .from("sesiones_club")
            .insert(NuevaSesion(club_id: clubId, modo: modo, creado_por: userId))
            .select().single().execute().value
        sesionActiva = sesion
        return sesion
    }

    func cargarSesionActiva(clubId: UUID) async {
        let sesiones: [SesionClub] = (try? await SupabaseService.client
            .from("sesiones_club").select()
            .eq("club_id", value: clubId.uuidString)
            .in("estado", values: ["esperando", "corriendo"])
            .order("creado_en", ascending: false)
            .limit(1).execute().value) ?? []
        let sesion = sesiones.first
        if sesion?.id != sesionActiva?.id { sesionActiva = sesion }
        if let s = sesionActiva { await cargarRutasPropuestas(sesionId: s.id) }
    }

    func proponerRuta(sesionId: UUID, userId: UUID, nombreUsuario: String, routePlanJson: String) async throws {
        struct NuevaRuta: Encodable {
            let sesion_id: UUID; let user_id: UUID; let nombre_usuario: String; let route_plan_json: String
        }
        try await SupabaseService.client
            .from("rutas_propuestas")
            .insert(NuevaRuta(sesion_id: sesionId, user_id: userId, nombre_usuario: nombreUsuario, route_plan_json: routePlanJson))
            .execute()
        await cargarRutasPropuestas(sesionId: sesionId)
    }

    func votar(sesionId: UUID, rutaId: UUID, userId: UUID) async throws {
        struct Params: Encodable { let p_sesion_id: UUID; let p_ruta_id: UUID }
        try await SupabaseService.client
            .rpc("votar_ruta", params: Params(p_sesion_id: sesionId, p_ruta_id: rutaId))
            .execute()
        miVotoId = rutaId
        await cargarRutasPropuestas(sesionId: sesionId)
    }

    func iniciarCorrida(sesionId: UUID) async throws -> String? {
        struct Params: Encodable { let p_sesion_id: UUID }
        let resp = try await SupabaseService.client
            .rpc("iniciar_corrida_club", params: Params(p_sesion_id: sesionId))
            .execute()
        // RPC returns the JSON string directly
        let data = resp.data
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = str.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return trimmed.isEmpty ? nil : trimmed
    }

    func cargarRutasPropuestas(sesionId: UUID) async {
        let result: [RutaPropuesta]? = try? await SupabaseService.client
            .from("rutas_propuestas").select()
            .eq("sesion_id", value: sesionId.uuidString)
            .order("votos", ascending: false).execute().value
        rutasPropuestas = result ?? []
    }

    // MARK: - Helpers

    private func generarCodigo() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }
}
