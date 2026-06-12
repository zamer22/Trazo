import Foundation

struct Club: Identifiable, Codable, Hashable {
    let id: UUID
    var nombre: String
    var descripcion: String?
    let codigo: String
    var esPublico: Bool
    let creadoPor: UUID
    let creadoEn: Date

    enum CodingKeys: String, CodingKey {
        case id, nombre, descripcion, codigo
        case esPublico = "es_publico"
        case creadoPor = "creado_por"
        case creadoEn = "creado_en"
    }
}

struct ClubMiembro: Codable {
    let clubId: UUID
    let userId: UUID
    let rol: String
    let unidoEn: Date

    enum CodingKeys: String, CodingKey {
        case clubId = "club_id"
        case userId = "user_id"
        case rol
        case unidoEn = "unido_en"
    }
}

struct ClubMensaje: Identifiable, Codable {
    let id: UUID
    let clubId: UUID
    let userId: UUID
    let nombreUsuario: String
    let contenido: String
    let creadoEn: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case userId = "user_id"
        case nombreUsuario = "nombre_usuario"
        case contenido
        case creadoEn = "creado_en"
    }
}

struct SesionClub: Identifiable, Codable {
    let id: UUID
    let clubId: UUID
    let modo: String
    var estado: String
    var rutaGanadoraJson: String?
    let creadoPor: UUID
    let creadoEn: Date

    enum CodingKeys: String, CodingKey {
        case id
        case clubId = "club_id"
        case modo, estado
        case rutaGanadoraJson = "ruta_ganadora_json"
        case creadoPor = "creado_por"
        case creadoEn = "creado_en"
    }
}

struct RutaPropuesta: Identifiable, Codable {
    let id: UUID
    let sesionId: UUID
    let userId: UUID
    let nombreUsuario: String
    let routePlanJson: String
    var votos: Int
    let creadoEn: Date

    enum CodingKeys: String, CodingKey {
        case id
        case sesionId = "sesion_id"
        case userId = "user_id"
        case nombreUsuario = "nombre_usuario"
        case routePlanJson = "route_plan_json"
        case votos
        case creadoEn = "creado_en"
    }
}
