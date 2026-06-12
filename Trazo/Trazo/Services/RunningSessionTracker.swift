import CoreLocation
import Foundation

@MainActor
@Observable
final class RunningSessionTracker {

    // MARK: - Estado público

    private(set) var elapsedSeconds: Int = 0
    private(set) var distanciaRecorridaKm: Double = 0
    private(set) var ritmoActualStr: String = "--:-- /km"
    private(set) var caloriasQuemadas: Int = 0
    private(set) var indiceMasCercano: Int = 0
    private(set) var estaActivo: Bool = false

    var tiempoRestanteMin: Int {
        let restante = max(0, plan.distanceKm - distanciaRecorridaKm)
        let paceMinPerKm = ritmoActualSegundos > 0
            ? Double(ritmoActualSegundos) / 60.0
            : (plan.estimatedMinutes > 0 ? Double(plan.estimatedMinutes) / plan.distanceKm : 6.5)
        return max(0, Int((restante * paceMinPerKm).rounded()))
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var coordenadasCubiertas: [CLLocationCoordinate2D] {
        guard indiceMasCercano > 0 else { return [] }
        return Array(plan.coordinates.prefix(indiceMasCercano + 1))
    }

    var coordenadasRestantes: [CLLocationCoordinate2D] {
        guard indiceMasCercano < plan.coordinates.count else { return [] }
        return Array(plan.coordinates.suffix(from: indiceMasCercano))
    }

    var porcentajeCompletado: Double {
        guard plan.distanceKm > 0 else { return 0 }
        return min(1.0, distanciaRecorridaKm / plan.distanceKm)
    }

    var haTerminado: Bool {
        guard let destino = plan.coordinates.last,
              let actual = ultimaUbicacionGPS else { return false }
        let distAlDestino = actual.distance(from: CLLocation(latitude: destino.latitude, longitude: destino.longitude))
        return distAlDestino <= 18
    }

    private(set) var distanciaARutaM: Double = 0

    var estaFueraDeRuta: Bool { distanciaARutaM > 50 }

    // MARK: - Estado privado

    let plan: RoutePlan
    private var timerTask: Task<Void, Never>?
    private var ventanaPace: [(fecha: Date, ubicacion: CLLocation)] = []
    private var ritmoActualSegundos: Int = 0
    private var distanciaAcumuladaConPesos: Double = 0
    private var ultimaUbicacionGPS: CLLocation?

    // MARK: - Init

    init(plan: RoutePlan) {
        self.plan = plan
    }

    // MARK: - Control

    func iniciar() {
        estaActivo = true
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, self.estaActivo else { continue }
                self.elapsedSeconds += 1
            }
        }
    }

    func pausar() {
        estaActivo = false
        timerTask?.cancel()
    }

    // MARK: - Actualización de ubicación

    func actualizarUbicacion(_ coordenada: CLLocationCoordinate2D) {
        let nuevoIndice = encontrarIndiceMasCercano(a: coordenada)
        let locUsuario = CLLocation(latitude: coordenada.latitude, longitude: coordenada.longitude)
        let puntoCercano = plan.coordinates[nuevoIndice]
        distanciaARutaM = locUsuario.distance(from: CLLocation(latitude: puntoCercano.latitude, longitude: puntoCercano.longitude))

        if nuevoIndice > indiceMasCercano { indiceMasCercano = nuevoIndice }

        if estaActivo, let previa = ultimaUbicacionGPS {
            let delta = locUsuario.distance(from: previa)
            if delta >= 1.5 && delta <= 60 {
                distanciaAcumuladaConPesos += delta
                distanciaRecorridaKm = distanciaAcumuladaConPesos / 1000
            }
        }
        ultimaUbicacionGPS = locUsuario
        actualizarCalorias()
    }

    func actualizarVelocidad(_ location: CLLocation) {
        guard estaActivo else { return }
        let ahora = Date()
        ventanaPace.append((ahora, location))

        // Mantener ventana de 60 segundos
        let limite = ahora.addingTimeInterval(-60)
        ventanaPace = ventanaPace.filter { $0.fecha > limite }

        guard ventanaPace.count >= 3 else { return }
        let primero = ventanaPace.first!
        let distanciaVentanaM = location.distance(from: primero.ubicacion)
        let tiempoVentanaSeg = ahora.timeIntervalSince(primero.fecha)

        guard distanciaVentanaM > 30, tiempoVentanaSeg > 5 else { return }
        // Pace en seg/km
        let paceSegPerKm = tiempoVentanaSeg / (distanciaVentanaM / 1000)
        ritmoActualSegundos = Int(paceSegPerKm)
        let m = ritmoActualSegundos / 60
        let s = ritmoActualSegundos % 60
        ritmoActualStr = String(format: "%d:%02d /km", m, s)
    }

    // MARK: - Privado

    private func encontrarIndiceMasCercano(a coord: CLLocationCoordinate2D) -> Int {
        let locUsuario = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        // Buscar solo hacia adelante (±60 puntos del índice actual) para evitar saltos
        let inicio = max(0, indiceMasCercano - 3)
        let fin = min(plan.coordinates.count - 1, indiceMasCercano + 60)
        var mejorIndice = indiceMasCercano
        var mejorDist = Double.infinity
        for i in inicio...fin {
            let p = plan.coordinates[i]
            let d = locUsuario.distance(from: CLLocation(latitude: p.latitude, longitude: p.longitude))
            if d < mejorDist {
                mejorDist = d
                mejorIndice = i
            }
        }
        return mejorIndice
    }

    private func distanciaEntreCoords(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private func actualizarCalorias() {
        let weight = plan.estimatedCalories > 0
            ? Double(plan.estimatedCalories) / max(plan.distanceKm, 0.1) / 1.036
            : 70.0
        caloriasQuemadas = max(0, Int((distanciaRecorridaKm * weight * 1.036).rounded()))
    }
}
