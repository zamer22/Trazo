import AVFoundation
import CoreLocation

// MARK: - Giro detectado

private struct GiroDetectado {
    let indice: Int
    let tipo: String // "izquierda" | "derecha" | "giro_izq" | "giro_der"
    var nombreCalle: String?
    var anunciadoLejos = false  // ~200m antes
    var anunciadoCerca = false  // ~50m antes
}

// MARK: - Service

@MainActor
@Observable
final class VoiceNavigationService {

    // MARK: - Estado

    private(set) var activo: Bool = false

    // MARK: - Privado

    private let synth = AVSpeechSynthesizer()
    private var giros: [GiroDetectado] = []
    private var distanciasAcumuladas: [Double] = [] // metros desde inicio para cada índice
    private var ultimoAnuncioFueraDeRuta = Date.distantPast
    private var ultimoAnuncioPin = Date.distantPast
    private let coordenadas: [CLLocationCoordinate2D]

    // MARK: - Init

    init(coordenadas: [CLLocationCoordinate2D]) {
        self.coordenadas = coordenadas
        precomputarDistancias()
        detectarGiros()
        configurarAudio()
        Task { await geocodificarGiros() }
    }

    // MARK: - API pública

    func iniciarRuta() {
        activo = true
        guard coordenadas.count >= 2 else { return }
        let rumbo = calcularRumbo(desde: coordenadas[0], hacia: coordenadas[min(3, coordenadas.count - 1)])
        hablar("Ruta iniciada. Dirígete hacia el \(nombreRumbo(rumbo)).")
    }

    func actualizarPosicion(indiceActual: Int) {
        guard activo else { return }
        let distanciaActual = distanciasAcumuladas[safe: indiceActual] ?? 0

        for i in giros.indices {
            let distanciaAlGiro = distanciasAcumuladas[safe: giros[i].indice] ?? 0
            let metros = distanciaAlGiro - distanciaActual

            // Ya pasamos este giro
            guard metros > -30 else { continue }

            let textoGiro = textoParaGiro(giros[i])

            if metros < 55 && !giros[i].anunciadoCerca {
                giros[i].anunciadoCerca = true
                hablar(textoGiro)
            } else if metros < 220 && metros >= 55 && !giros[i].anunciadoLejos {
                giros[i].anunciadoLejos = true
                let metros200 = Int((metros / 50).rounded()) * 50
                hablar("En \(metros200) metros, \(textoGiro)")
            }
        }
    }

    func anunciarFueraDeRuta() {
        guard activo else { return }
        let ahora = Date()
        guard ahora.timeIntervalSince(ultimoAnuncioFueraDeRuta) > 12 else { return }
        ultimoAnuncioFueraDeRuta = ahora
        hablar("Te saliste de la ruta. Regresa al camino marcado.")
    }

    func anunciarPinCercano(_ etiqueta: String) {
        guard activo else { return }
        let ahora = Date()
        guard ahora.timeIntervalSince(ultimoAnuncioPin) > 20 else { return }
        ultimoAnuncioPin = ahora
        hablar("Precaución: \(etiqueta) a metros.")
    }

    func anunciarCompletada() {
        activo = false
        hablar("¡Felicidades! Completaste la ruta. Buen trabajo.")
    }

    func detener() {
        activo = false
        synth.stopSpeaking(at: .immediate)
    }

    // MARK: - Hablar

    private func hablar(_ texto: String) {
        synth.stopSpeaking(at: .word)
        let utterance = AVSpeechUtterance(string: texto)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-MX")
            ?? AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = 0.50
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        synth.speak(utterance)
    }

    // MARK: - Precomputación

    private func precomputarDistancias() {
        var acum = 0.0
        distanciasAcumuladas = [0.0]
        for i in 1..<coordenadas.count {
            acum += distanciaM(coordenadas[i - 1], coordenadas[i])
            distanciasAcumuladas.append(acum)
        }
    }

    private func detectarGiros() {
        guard coordenadas.count > 4 else { return }
        var resultado: [GiroDetectado] = []

        // Mínima separación entre giros detectados (evita duplicados)
        var ultimoGiroIndice = -20

        for i in 2..<(coordenadas.count - 2) {
            guard i - ultimoGiroIndice > 8 else { continue }

            let rumboAntes  = calcularRumbo(desde: coordenadas[i - 2], hacia: coordenadas[i])
            let rumboDepues = calcularRumbo(desde: coordenadas[i],     hacia: coordenadas[i + 2])
            let delta = diferenciaAngular(rumboAntes, rumboDepues)

            if abs(delta) >= 28 {
                let tipo: String
                switch abs(delta) {
                case 28..<55:  tipo = delta > 0 ? "dobla a la derecha"   : "dobla a la izquierda"
                case 55..<120: tipo = delta > 0 ? "gira a la derecha"    : "gira a la izquierda"
                default:       tipo = delta > 0 ? "da vuelta a la derecha" : "da vuelta a la izquierda"
                }
                resultado.append(GiroDetectado(indice: i, tipo: tipo))
                ultimoGiroIndice = i
            }
        }
        giros = resultado
    }

    // MARK: - Geocodificación

    private func geocodificarGiros() async {
        let geocoder = CLGeocoder()
        for i in giros.indices {
            let coord = coordenadas[giros[i].indice]
            let loc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            if let placemarks = try? await geocoder.reverseGeocodeLocation(loc),
               let nombre = placemarks.first?.thoroughfare {
                giros[i].nombreCalle = nombre
            }
            // Respetar límite de geocoder (~1 req/s)
            try? await Task.sleep(for: .milliseconds(1200))
        }
    }

    // MARK: - Texto del giro

    private func textoParaGiro(_ giro: GiroDetectado) -> String {
        if let calle = giro.nombreCalle {
            return "\(giro.tipo) hacia \(calle)."
        }
        return "\(giro.tipo)."
    }

    // MARK: - Helpers geométricos

    private func calcularRumbo(desde: CLLocationCoordinate2D, hacia: CLLocationCoordinate2D) -> Double {
        let lat1 = desde.latitude * .pi / 180
        let lat2 = hacia.latitude * .pi / 180
        let dLon = (hacia.longitude - desde.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func diferenciaAngular(_ a: Double, _ b: Double) -> Double {
        var d = b - a
        while d > 180  { d -= 360 }
        while d < -180 { d += 360 }
        return d
    }

    private func distanciaM(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private func nombreRumbo(_ g: Double) -> String {
        switch g {
        case 0..<22.5, 337.5...360: return "norte"
        case 22.5..<67.5:  return "noreste"
        case 67.5..<112.5: return "este"
        case 112.5..<157.5: return "sureste"
        case 157.5..<202.5: return "sur"
        case 202.5..<247.5: return "suroeste"
        case 247.5..<292.5: return "oeste"
        default:            return "noroeste"
        }
    }

    // MARK: - Audio session

    private func configurarAudio() {
        #if !os(macOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
        try? session.setActive(true)
        #endif
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
