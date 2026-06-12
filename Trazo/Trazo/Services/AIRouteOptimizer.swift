import CoreLocation
import Foundation
import FoundationModels

@Generable
struct RecomendacionRuta {
    @Guide(description: "Modo recomendado: exactamente 'ida' o 'ida_y_vuelta'.")
    var modoRecomendado: String

    @Guide(description: """
        Briefing personalizado en 3-4 oraciones. DEBES incluir datos numéricos concretos de estos factores:
        1. Tiempo estimado real basado en el ritmo actual del corredor para ESA distancia específica.
        2. Zona de frecuencia cardíaca esperada (% de FC máx si tienes edad, o zona cualitativa).
        3. Si el desnivel es manejable o exigente PARA ESTE corredor específico (según su VO₂ máx y nivel).
        4. Una recomendación accionable: hidratación, calentamiento, o ajuste de ritmo según su perfil.
        Usa números concretos. NO uses lenguaje genérico. Habla directamente al corredor en segunda persona.
        """)
    var razon: String

    @Guide(description: "Etiqueta de máximo 4 palabras que capture la esencia de la ruta para este corredor.")
    var etiqueta: String
}

@MainActor
@Observable
final class AIRouteOptimizer {

    enum Estado {
        case inactivo
        case analizando
        case listo(RoutePlan, RecomendacionRuta)
        case error(String)
    }

    var estado: Estado = .inactivo

    func optimizar(
        destino: MapDestination,
        origen: CLLocationCoordinate2D,
        perfil: UserProfile?
    ) async {
        estado = .analizando

        async let idaTask: RoutePlan? = try? await RouteCalculator.calculate(
            to: destino, from: origen, profile: perfil)
        async let vueltaTask: RoutePlan? = try? await RouteCalculator.calculateRoundTrip(
            to: destino, from: origen, profile: perfil)

        let (planIda, planVuelta) = await (idaTask, vueltaTask)

        guard planIda != nil || planVuelta != nil else {
            estado = .error("No se encontraron rutas hacia ese destino.")
            return
        }

        guard SystemLanguageModel.default.isAvailable else {
            let fallback = elegirFallback(ida: planIda, vuelta: planVuelta, perfil: perfil)
            var plan = fallback.0
            plan.aiRazon = briefingFallback(plan: plan, perfil: perfil)
            estado = .listo(plan, RecomendacionRuta(
                modoRecomendado: fallback.1,
                razon: plan.aiRazon ?? "",
                etiqueta: "Ruta recomendada"
            ))
            return
        }

        let prompt = construirPrompt(destino: destino, ida: planIda, vuelta: planVuelta, perfil: perfil)

        do {
            let session = LanguageModelSession(instructions: instrucciones())
            let respuesta = try await session.respond(to: prompt, generating: RecomendacionRuta.self)
            let modo = respuesta.content.modoRecomendado.lowercased()
            let plan: RoutePlan
            if modo.contains("vuelta"), let v = planVuelta {
                plan = v
            } else if let i = planIda {
                plan = i
            } else if let v = planVuelta {
                plan = v
            } else {
                estado = .error("No se encontró un Trazo caminable.")
                return
            }
            var planConRazon = plan
            planConRazon.aiRazon = respuesta.content.razon
            estado = .listo(planConRazon, respuesta.content)
        } catch {
            let fallback = elegirFallback(ida: planIda, vuelta: planVuelta, perfil: perfil)
            var plan = fallback.0
            plan.aiRazon = briefingFallback(plan: plan, perfil: perfil)
            estado = .listo(plan, RecomendacionRuta(
                modoRecomendado: fallback.1,
                razon: plan.aiRazon ?? "",
                etiqueta: "Ruta recomendada"
            ))
        }
    }

    func reiniciar() { estado = .inactivo }

    // MARK: - Fallback sin IA

    private func elegirFallback(ida: RoutePlan?, vuelta: RoutePlan?, perfil: UserProfile?) -> (RoutePlan, String) {
        let nivel = perfil?.fitnessLevelRaw ?? "Intermedio"
        if let v = vuelta, nivel == "Avanzado" { return (v, "ida_y_vuelta") }
        if let i = ida { return (i, "ida") }
        if let v = vuelta { return (v, "ida_y_vuelta") }
        return (ida ?? vuelta!, "ida")
    }

    private func briefingFallback(plan: RoutePlan, perfil: UserProfile?) -> String {
        var partes: [String] = []
        let ritmo = perfil?.averagePaceMinPerKm ?? 6.5
        let tiempoReal = Int(plan.distanceKm * ritmo)
        partes.append("A tu ritmo de \(perfil?.formattedPace ?? "6:30 /km"), completarás esta ruta de \(String(format: "%.1f", plan.distanceKm)) km en aproximadamente \(tiempoReal) minutos.")
        if let vo2 = perfil?.vo2Max {
            let capacidad = vo2 > 50 ? "alta" : vo2 > 35 ? "moderada" : "básica"
            partes.append("Con tu VO₂ máx de \(Int(vo2)) mL/kg/min (capacidad aeróbica \(capacidad)), el terreno \(plan.desnivel.lowercased()) no debería representar un problema.")
        }
        if plan.gananciaElevacionM > 100 {
            partes.append("El desnivel de \(plan.gananciaElevacionM) m requiere ajustar el ritmo en las subidas.")
        }
        return partes.joined(separator: " ")
    }

    // MARK: - Instrucciones del modelo

    private func instrucciones() -> String {
        """
        Eres un coach de running experto en fisiología del ejercicio. Analizas rutas y das briefings personalizados.
        REGLAS:
        - Elige entre 'ida' o 'ida_y_vuelta' el modo óptimo para ESTE corredor específico.
        - El briefing DEBE mencionar números concretos: tiempo estimado en minutos, km exactos, metros de desnivel, FC esperada si tienes datos de edad.
        - Si tienes VO₂ máx, calcula el porcentaje de capacidad aeróbica que usará el corredor (esfuerzo estimado = distancia×ritmo / capacidad).
        - Si tienes FC reposo y edad, estima la zona de entrenamiento (FC máx ≈ 220 − edad, zona 2 = 60-70%, zona 3 = 70-80%, zona 4 = 80-90%).
        - Adapta el tono: sé más cauteloso con principiantes, más exigente con avanzados.
        - Si el corredor prefiere rutas planas pero la ruta tiene mucho desnivel, menciónalo.
        - Termina SIEMPRE con una recomendación accionable específica (no genérica).
        """
    }

    // MARK: - Construcción del prompt con TODOS los datos de salud

    private func construirPrompt(
        destino: MapDestination,
        ida: RoutePlan?, vuelta: RoutePlan?,
        perfil: UserProfile?
    ) -> String {
        var partes: [String] = ["ANÁLISIS DE RUTA"]

        partes.append("Destino: \(destino.name).")

        if let i = ida {
            partes.append("OPCIÓN IDA: \(String(format: "%.1f", i.distanceKm)) km | desnivel +\(i.gananciaElevacionM) m | tiempo estimado ~\(i.estimatedMinutes) min | terreno: \(i.desnivel).")
        }
        if let v = vuelta {
            partes.append("OPCIÓN IDA+VUELTA: \(String(format: "%.1f", v.distanceKm)) km | desnivel +\(v.gananciaElevacionM) m | tiempo estimado ~\(v.estimatedMinutes) min | terreno: \(v.desnivel).")
        }

        partes.append("--- PERFIL DEL CORREDOR ---")

        guard let p = perfil else {
            partes.append("Sin datos de perfil disponibles.")
            partes.append("Elige la opción más conservadora.")
            return partes.joined(separator: "\n")
        }

        partes.append("Nivel: \(p.fitnessLevelRaw).")
        partes.append("Peso: \(String(format: "%.0f", p.weightKg)) kg.")
        partes.append("Ritmo actual: \(p.formattedPace) min/km.")

        if let h = p.heightCm { partes.append("Altura: \(Int(h)) cm.") }
        if let a = p.age {
            partes.append("Edad: \(a) años.")
            let fcMax = 220 - a
            partes.append("FC máxima estimada: \(fcMax) lpm.")
            if let fcR = p.restingHR {
                let fcReserva = fcMax - fcR
                partes.append("FC reposo: \(fcR) lpm. Reserva cardíaca: \(fcReserva) lpm.")
            }
        }
        if let fcR = p.restingHR, p.age == nil {
            partes.append("FC reposo: \(fcR) lpm.")
        }
        if let vo2 = p.vo2Max {
            let categoria = vo2 > 55 ? "élite" : vo2 > 45 ? "buena" : vo2 > 35 ? "promedio" : "básica"
            partes.append("VO₂ máx: \(String(format: "%.1f", vo2)) mL/kg/min (capacidad aeróbica \(categoria)).")
        }
        if let s = p.sex { partes.append("Sexo: \(s).") }
        if let r = p.weeklyRuns { partes.append("Corridas por semana: \(r).") }
        partes.append(p.preferFlatRoutes ? "Prefiere rutas planas (evita desnivel)." : "Acepta terrenos con desnivel.")
        partes.append(p.avoidHighways ? "Evita autopistas." : "No restringe tipo de vialidad.")

        partes.append("--- TAREA ---")
        partes.append("1. Elige el modo óptimo (ida o ida_y_vuelta) para este corredor.")
        partes.append("2. Genera un briefing personalizado usando los datos numéricos de salud disponibles.")
        partes.append("3. Incluye: tiempo real esperado, esfuerzo cardíaco estimado, viabilidad del desnivel para este corredor.")

        return partes.joined(separator: "\n")
    }
}
