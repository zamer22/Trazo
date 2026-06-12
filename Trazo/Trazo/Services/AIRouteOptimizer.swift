import CoreLocation
import Foundation
import FoundationModels

@Generable
struct RecomendacionRuta {
    @Guide(description: "Modo recomendado: exactamente 'ida' o 'ida_y_vuelta'.")
    var modoRecomendado: String

    @Guide(description: """
        Briefing en 2-3 oraciones en español muy sencillo, como si le hablaras a un amigo que va a salir a correr.
        REGLAS ESTRICTAS:
        - NUNCA uses: VO₂ máx, FC máxima, zona cardíaca, lactato, reserva cardíaca. NINGÚN término médico.
        - SÍ puedes decir: 'tu resistencia', 'tu corazón va a latir bastante', 'ritmo cómodo donde puedes hablar'.
        - Menciona cuántos minutos va a tardar esta persona y si el terreno tiene cuestas o es plano.
        - Para describir desnivel usa comparaciones: 'como subir 4 pisos', 'casi plano', 'vas a sentir las subidas'.
        - Adapta el tono: anima al principiante, sé directo con el avanzado.
        - Última oración: UNA recomendación práctica simple ('toma agua antes de salir', 'calienta 5 min', etc).
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
        partes.append("A tu ritmo vas a tardar unos \(tiempoReal) minutos en cubrir los \(String(format: "%.1f", plan.distanceKm)) km de esta ruta.")
        if plan.gananciaElevacionM > 150 {
            partes.append("El terreno tiene cuestas que vas a sentir, como subir varios pisos en total — ve a un ritmo que te permita hablar.")
        } else if plan.gananciaElevacionM > 50 {
            partes.append("El terreno tiene algo de subida pero nada exigente — podrás mantener un ritmo constante.")
        } else {
            partes.append("El terreno es prácticamente plano, ideal para mantener un paso parejo.")
        }
        partes.append("Toma agua antes de salir y calienta 5 minutos caminando.")
        return partes.joined(separator: " ")
    }

    // MARK: - Instrucciones del modelo

    private func instrucciones() -> String {
        """
        Eres un entrenador de running que explica rutas en español sencillo, como si le hablaras a un amigo.
        REGLAS:
        - Elige 'ida' o 'ida_y_vuelta' según lo que sea mejor para esta persona.
        - Habla en lenguaje simple, sin términos médicos. Ejemplos:
          * En vez de 'VO₂ máx' di 'tu resistencia cardiovascular'.
          * En vez de 'zona 2 de frecuencia cardíaca' di 'un ritmo cómodo donde puedes hablar'.
          * En vez de 'FC máxima' di 'el límite de pulsaciones de tu corazón'.
        - Siempre menciona cuántos minutos tardará esta persona y a qué ritmo va.
        - Describe el desnivel con comparaciones reales: 'es como subir 3 pisos', 'terreno casi plano', 'hay cuestas que notarás'.
        - Si la persona es principiante, sé animador y tranquilizador. Si es avanzado, sé más directo.
        - Termina con UNA recomendación práctica y simple: tomar agua, calentar 5 minutos, ir despacio al principio, etc.
        - Máximo 4 oraciones. Nada de listas ni bullets, escribe como párrafo natural.
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

        partes.append("--- PREFERENCIAS DE RUTA ---")
        partes.append("Los corredores prefieren caminos rectos y continuos. Evita rutas en zigzag innecesario.")
        partes.append("Evita avenidas muy transitadas o peligrosas (como Constitución, bulevardes de alta velocidad, autopistas, puentes vehiculares).")
        partes.append("Prefiere calles interiores, parques, ciclovías o colonias tranquilas cuando es posible.")

        partes.append("--- TAREA ---")
        partes.append("1. Elige el modo óptimo (ida o ida_y_vuelta) para este corredor.")
        partes.append("2. Genera un briefing en lenguaje sencillo: tiempo esperado, sensación de esfuerzo, descripción simple del terreno.")
        partes.append("3. Termina con una recomendación práctica de 1 oración.")

        return partes.joined(separator: "\n")
    }
}
