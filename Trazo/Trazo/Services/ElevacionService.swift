import CoreLocation
import Foundation
import Supabase

struct PuntoElevacion: Codable, Sendable {
    let latitud: Double
    let longitud: Double
    let elevacion: Int
}

enum ElevacionService {

    // Calcula ganancia de elevación total (metros positivos) para una lista de coordenadas
    static func calcularGanancia(coordenadas: [CLLocationCoordinate2D]) async -> Int {
        guard coordenadas.count >= 2 else { return 0 }

        let lats = coordenadas.map(\.latitude)
        let lons = coordenadas.map(\.longitude)
        let buffer = 0.006 // ~600m buffer alrededor del bbox

        guard let puntos = try? await fetchEnCaja(
            latMin: (lats.min() ?? 0) - buffer,
            latMax: (lats.max() ?? 0) + buffer,
            lonMin: (lons.min() ?? 0) - buffer,
            lonMax: (lons.max() ?? 0) + buffer
        ), !puntos.isEmpty else { return 0 }

        // Muestreo cada ~150m para no saturar con lookups
        let muestra = samplear(coordenadas: coordenadas, intervaloMetros: 150)
        let elevaciones = muestra.compactMap { elevacionCercana(en: $0, desde: puntos) }

        var ganancia = 0
        for i in 1..<elevaciones.count {
            let delta = elevaciones[i] - elevaciones[i - 1]
            if delta > 2 { ganancia += delta } // filtro de ruido < 2m
        }
        return ganancia
    }

    private static func fetchEnCaja(
        latMin: Double, latMax: Double,
        lonMin: Double, lonMax: Double
    ) async throws -> [PuntoElevacion] {
        try await SupabaseService.client
            .from("elevaciones")
            .select("latitud,longitud,elevacion")
            .gte("latitud", value: latMin)
            .lte("latitud", value: latMax)
            .gte("longitud", value: lonMin)
            .lte("longitud", value: lonMax)
            .execute()
            .value
    }

    private static func elevacionCercana(
        en coord: CLLocationCoordinate2D,
        desde puntos: [PuntoElevacion]
    ) -> Int? {
        puntos.min {
            distSq(coord, $0) < distSq(coord, $1)
        }.map(\.elevacion)
    }

    private static func distSq(_ c: CLLocationCoordinate2D, _ p: PuntoElevacion) -> Double {
        let dLat = c.latitude - p.latitud
        let dLon = c.longitude - p.longitud
        return dLat * dLat + dLon * dLon
    }

    private static func samplear(
        coordenadas: [CLLocationCoordinate2D],
        intervaloMetros: Double
    ) -> [CLLocationCoordinate2D] {
        guard !coordenadas.isEmpty else { return [] }
        var resultado = [coordenadas[0]]
        var acumulado = 0.0
        for i in 1..<coordenadas.count {
            let prev = coordenadas[i - 1]
            let curr = coordenadas[i]
            acumulado += CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                .distance(from: CLLocation(latitude: curr.latitude, longitude: curr.longitude))
            if acumulado >= intervaloMetros {
                resultado.append(curr)
                acumulado = 0
            }
        }
        return resultado
    }
}
