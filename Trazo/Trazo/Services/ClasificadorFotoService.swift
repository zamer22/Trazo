import Foundation
import FoundationModels
import UIKit
import Vision

@Generable
private struct ClasificacionPin {
    @Guide(description: "Tipo de problema para corredores: 'bache', 'basura', 'inundacion', 'obra', 'obstaculo', 'peligro', o 'ninguno' si la foto no muestra un problema real en la vía")
    var tipo: String

    @Guide(description: "Confianza de 0.0 a 1.0")
    var confianza: Double
}

@MainActor
@Observable
final class ClasificadorFotoService {

    enum Estado {
        case inactivo
        case analizando
        case detectado(tipo: String)
        case sinProblema
        case error(String)
    }

    var estado: Estado = .inactivo

    func analizar(_ imagen: UIImage) async {
        estado = .analizando

        // Paso 1: Vision extrae etiquetas de la imagen
        let etiquetas = await extraerEtiquetas(imagen)

        guard !etiquetas.isEmpty else {
            estado = .error("No se pudo analizar la imagen.")
            return
        }

        // Paso 2: Foundation Models clasifica si es un problema para corredores
        guard SystemLanguageModel.default.isAvailable else {
            // Fallback: clasificación heurística con Vision
            estado = fallbackHeuristico(etiquetas)
            return
        }

        await clasificarConIA(etiquetas: etiquetas)
    }

    func reiniciar() {
        estado = .inactivo
    }

    // MARK: - Vision

    private func extraerEtiquetas(_ imagen: UIImage) async -> [String] {
        guard let cgImage = imagen.cgImage else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
            return (request.results ?? [])
                .filter { $0.confidence > 0.2 }
                .prefix(20)
                .map { $0.identifier }
        }.value
    }

    // MARK: - Foundation Models

    private func clasificarConIA(etiquetas: [String]) async {
        let prompt = """
        Un corredor tomó una foto en su ruta. Vision AI detectó estas etiquetas:
        \(etiquetas.joined(separator: ", "))

        ¿Esto representa un problema físico real para corredores en una calle o banqueta?
        Solo clasifica como problema si las etiquetas sugieren claramente un obstáculo real en la vía pública.
        """
        do {
            let instrucciones = "Eres un clasificador de peligros viales para corredores urbanos. Eres estricto: solo marcas algo como problema si hay evidencia clara en las etiquetas."
            let session = LanguageModelSession(instructions: instrucciones)
            let respuesta = try await session.respond(to: prompt, generating: ClasificacionPin.self)
            let resultado = respuesta.content
            if resultado.tipo == "ninguno" || resultado.confianza < 0.55 {
                estado = .sinProblema
            } else {
                estado = .detectado(tipo: resultado.tipo)
            }
        } catch {
            estado = .error("No se pudo clasificar la imagen.")
        }
    }

    // MARK: - Heurístico (fallback sin IA)

    private func fallbackHeuristico(_ etiquetas: [String]) -> Estado {
        let joined = etiquetas.joined(separator: " ").lowercased()
        if joined.contains("water") || joined.contains("flood") || joined.contains("puddle") {
            return .detectado(tipo: "inundacion")
        }
        if joined.contains("construction") || joined.contains("machinery") {
            return .detectado(tipo: "obra")
        }
        if joined.contains("garbage") || joined.contains("trash") || joined.contains("waste") {
            return .detectado(tipo: "basura")
        }
        if joined.contains("pothole") || joined.contains("crack") || joined.contains("damaged") {
            return .detectado(tipo: "bache")
        }
        if joined.contains("barrier") || joined.contains("obstacle") || joined.contains("blocked") {
            return .detectado(tipo: "obstaculo")
        }
        return .sinProblema
    }
}
