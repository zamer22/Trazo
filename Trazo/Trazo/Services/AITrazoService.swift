import Foundation
import FoundationModels
import SwiftData

@Generable
struct IntentTrazo {
    @Guide(description: "Distancia EXACTA en kilómetros que pidió el usuario. Si el usuario dijo un número, úsalo tal cual. Solo si no mencionó distancia, elige una apropiada al perfil.")
    var distanciaKm: Double

    @Guide(description: "Dificultad exactamente como una de estas palabras: plana, moderada, exigente. Si el usuario la especificó úsala; si no, infiere del perfil y del tono del mensaje.")
    var dificultad: String

    @Guide(description: "Etiqueta motivadora de máximo 5 palabras en español que resuma la ruta")
    var etiqueta: String
}

@MainActor
@Observable
final class AITrazoService {

    enum Estado {
        case inactivo
        case procesando
        case listo(IntentTrazo)
        case error(String)
    }

    var estado: Estado = .inactivo

    func interpretar(_ prompt: String, perfil: UserProfile?) async {
        estado = .procesando

        guard SystemLanguageModel.default.isAvailable else {
            estado = .error("Modelos de IA no disponibles en este dispositivo.")
            return
        }

        let instrucciones = buildInstrucciones(perfil)

        do {
            let session = LanguageModelSession(instructions: instrucciones)
            let respuesta = try await session.respond(to: prompt, generating: IntentTrazo.self)
            estado = .listo(respuesta.content)
        } catch {
            estado = .error("No pude interpretar tu solicitud. Intenta de nuevo.")
        }
    }

    func reiniciar() {
        estado = .inactivo
    }

    private func buildInstrucciones(_ perfil: UserProfile?) -> String {
        var partes = [
            "Eres un asistente de running. Tu trabajo es interpretar lo que el usuario quiere correr.",
            "REGLA PRINCIPAL: lo que el usuario pide en su mensaje tiene prioridad absoluta.",
            "Si menciona distancia (ej: '2km', '10 kilómetros'), úsala exactamente.",
            "Si menciona dificultad ('suave', 'exigente', 'tranquilo'), respétala.",
            "El perfil del usuario es contexto secundario: úsalo SOLO para rellenar lo que el usuario NO especificó.",
            "Si el usuario dice 'sorpréndeme' o no da detalles, entonces sí usa el perfil para elegir algo interesante y apropiado.",
            "La dificultad debe ser exactamente: 'plana', 'moderada' o 'exigente'."
        ]
        if let perfil {
            partes.append("--- Perfil del corredor (contexto secundario) ---")
            partes.append("Nivel: \(perfil.fitnessLevelRaw).")
            partes.append("Ritmo promedio: \(perfil.formattedPace).")
            if let vo2 = perfil.vo2Max { partes.append("VO₂ máx: \(Int(vo2)).") }
            if let runs = perfil.weeklyRuns { partes.append("Corridas por semana: \(runs).") }
            if perfil.preferFlatRoutes { partes.append("Prefiere rutas planas cuando no especifica.") }
        }
        return partes.joined(separator: " ")
    }
}
