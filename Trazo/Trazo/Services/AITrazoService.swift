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

    @Guide(description: "Razón corta en 1-2 oraciones en español muy sencillo, sin tecnicismos. Habla directo al usuario: explica por qué esta distancia y dificultad le van bien. Ejemplo: 'Esta distancia va bien para tu ritmo y te va a dejar terminar cómodo.' Sin mencionar VO₂, FC, ni términos médicos.")
    var razon: String
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
            let km = 5.0
            let nivel = perfil?.fitnessLevelRaw ?? "Intermedio"
            estado = .listo(IntentTrazo(distanciaKm: km, dificultad: "moderada", etiqueta: "Trazo recomendado", razon: "Ruta moderada de \(Int(km)) km ideal para nivel \(nivel)."))
            return
        }

        let instrucciones = buildInstrucciones(perfil)

        do {
            let session = LanguageModelSession(instructions: instrucciones)
            let respuesta = try await session.respond(to: prompt, generating: IntentTrazo.self)
            estado = .listo(respuesta.content)
        } catch {
            let km = 5.0
            estado = .listo(IntentTrazo(distanciaKm: km, dificultad: "moderada", etiqueta: "Trazo recomendado", razon: "Ruta moderada basada en tu perfil."))
        }
    }

    func reiniciar() {
        estado = .inactivo
    }

    private func buildInstrucciones(_ perfil: UserProfile?) -> String {
        var partes = [
            "Eres un coach de running. Tu trabajo es interpretar lo que el usuario quiere correr respetando su prompt Y cuidando su salud.",
            "PRIORIDAD 1: el prompt del usuario. Si menciona distancia (ej: '5km'), úsala exactamente. Si menciona un lugar o tipo de ruta, respétalo.",
            "PRIORIDAD 2: el perfil del corredor. Si el perfil indica nivel Principiante o condición física baja, cap la distancia a 10km y la dificultad a moderada, aunque el usuario pida algo más exigente.",
            "Si el usuario dice 'sorpréndeme' o no da detalles, usa el perfil para elegir distancia y dificultad apropiadas.",
            "La dificultad debe ser exactamente: 'plana', 'moderada' o 'exigente'.",
            "En el campo 'razon', explica brevemente por qué elegiste estos parámetros considerando el prompt y el perfil."
        ]
        if let perfil {
            partes.append("--- Perfil del corredor ---")
            partes.append("Nivel: \(perfil.fitnessLevelRaw).")
            partes.append("Ritmo promedio: \(perfil.formattedPace).")
            if let vo2 = perfil.vo2Max { partes.append("VO₂ máx: \(Int(vo2)).") }
            if let runs = perfil.weeklyRuns { partes.append("Corridas por semana: \(runs).") }
            if perfil.preferFlatRoutes { partes.append("Prefiere rutas planas cuando no especifica.") }
        }
        return partes.joined(separator: " ")
    }
}
