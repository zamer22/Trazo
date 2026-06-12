import Foundation
import Supabase

struct RemoteUserProfile: Codable, Sendable {
    let id: UUID
    let nombreUsuario: String
    let correo: String
    let nivel: String
    let puntos: Int
    let pesoKg: Double?
    let alturaCm: Double?
    let edad: Int?
    let sexo: String?
    let fcReposo: Int?
    let vo2Max: Double?
    let ritmoPromedioMinPerKm: Double?
    let corridasSemanales: Int?
    let prefiereRutasPlanas: Bool
    let evitaAutopistas: Bool
    let healthVinculado: Bool
    let onboardingCompletado: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nombreUsuario = "nombre_usuario"
        case correo
        case nivel
        case puntos
        case pesoKg = "peso_kg"
        case alturaCm = "altura_cm"
        case edad
        case sexo
        case fcReposo = "fc_reposo"
        case vo2Max = "vo2_max"
        case ritmoPromedioMinPerKm = "ritmo_promedio_min_per_km"
        case corridasSemanales = "corridas_semanales"
        case prefiereRutasPlanas = "prefiere_rutas_planas"
        case evitaAutopistas = "evita_autopistas"
        case healthVinculado = "health_vinculado"
        case onboardingCompletado = "onboarding_completado"
    }
}

private struct UserProfileUpdate: Codable, Sendable {
    let nombreUsuario: String
    let nivel: String
    let pesoKg: Double?
    let alturaCm: Double?
    let edad: Int?
    let sexo: String?
    let fcReposo: Int?
    let vo2Max: Double?
    let ritmoPromedioMinPerKm: Double?
    let corridasSemanales: Int?
    let prefiereRutasPlanas: Bool
    let evitaAutopistas: Bool
    let healthVinculado: Bool
    let onboardingCompletado: Bool

    enum CodingKeys: String, CodingKey {
        case nombreUsuario = "nombre_usuario"
        case nivel
        case pesoKg = "peso_kg"
        case alturaCm = "altura_cm"
        case edad
        case sexo
        case fcReposo = "fc_reposo"
        case vo2Max = "vo2_max"
        case ritmoPromedioMinPerKm = "ritmo_promedio_min_per_km"
        case corridasSemanales = "corridas_semanales"
        case prefiereRutasPlanas = "prefiere_rutas_planas"
        case evitaAutopistas = "evita_autopistas"
        case healthVinculado = "health_vinculado"
        case onboardingCompletado = "onboarding_completado"
    }
}

@MainActor
enum UserProfileRepository {
    private static let table = "usuarios"

    static func fetch(userId: UUID) async throws -> RemoteUserProfile? {
        do {
            let remoto: RemoteUserProfile = try await SupabaseService.client
                .from(table)
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            return remoto
        } catch {
            return nil
        }
    }

    static func upsert(_ profile: UserProfile) async throws {
        let payload = UserProfileUpdate(
            nombreUsuario: profile.displayName,
            nivel: profile.fitnessLevel.rawValue,
            pesoKg: profile.weightKg,
            alturaCm: profile.heightCm,
            edad: profile.age,
            sexo: profile.sex,
            fcReposo: profile.restingHR,
            vo2Max: profile.vo2Max,
            ritmoPromedioMinPerKm: profile.averagePaceMinPerKm,
            corridasSemanales: profile.weeklyRuns,
            prefiereRutasPlanas: profile.preferFlatRoutes,
            evitaAutopistas: profile.avoidHighways,
            healthVinculado: profile.healthLinked,
            onboardingCompletado: profile.hasCompletedOnboarding
        )
        try await SupabaseService.client
            .from(table)
            .update(payload)
            .eq("id", value: profile.id)
            .execute()
    }
}
