import CoreLocation
import FoundationModels
import SwiftUI

// MARK: - RunStats

struct RunStats: Identifiable {
    let id = UUID()
    let distanciaRecorridaKm: Double
    let elapsedSeconds: Int
    let ritmoStr: String
    let calorias: Int
    let completado: Bool
    let planDistanciaKm: Double
    let planGananciaElevacionM: Int

    var porcentaje: Double { min(1.0, distanciaRecorridaKm / max(planDistanciaKm, 0.001)) }
    var elapsedFormatted: String {
        let m = elapsedSeconds / 60; let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    var kmFaltaronStr: String { String(format: "%.2f", max(0, planDistanciaKm - distanciaRecorridaKm)) }
}

// MARK: - Foundation Models

@Generable
private struct ResumenRunIA {
    @Guide(description: "Mensaje de 2-3 oraciones. Si completó la ruta: celebración específica mencionando la distancia y tiempo exactos. Si no completó: aliento mencionando cuántos km logró vs el objetivo, tono positivo y motivador.")
    var mensaje: String

    @Guide(description: "Lista de exactamente 3 consejos de running MUY específicos a los números de esta corrida. PROHIBIDO ser genérico. Menciona valores concretos: ritmo actual, distancia, nivel, VO2max si aplica, frecuencia semanal. Cada tip en máximo 2 oraciones.")
    var protips: [String]
}

@MainActor
@Observable
private final class ResumenService {
    enum Estado { case cargando; case listo(ResumenRunIA); case error }
    var estado: Estado = .cargando

    func generar(stats: RunStats, perfil: UserProfile?) async {
        guard SystemLanguageModel.default.isAvailable else {
            estado = .listo(fallback(stats: stats))
            return
        }
        let prompt = buildPrompt(stats: stats, perfil: perfil)
        do {
            let session = LanguageModelSession(
                instructions: "Eres un coach de running experto. Analizas corridas y das consejos muy específicos basados en los datos reales del corredor."
            )
            let r = try await session.respond(to: prompt, generating: ResumenRunIA.self)
            estado = .listo(r.content)
        } catch {
            estado = .listo(fallback(stats: stats))
        }
    }

    private func buildPrompt(stats: RunStats, perfil: UserProfile?) -> String {
        var partes = [
            "Analiza esta corrida y genera un resumen personalizado:",
            "Corrida: \(String(format: "%.2f", stats.distanciaRecorridaKm)) km en \(stats.elapsedFormatted), ritmo \(stats.ritmoStr), \(stats.calorias) cal.",
            "Objetivo del plan: \(String(format: "%.1f", stats.planDistanciaKm)) km.",
            stats.completado ? "RESULTADO: Completó la ruta." : "RESULTADO: No completó — faltaron \(stats.kmFaltaronStr) km (\(Int(stats.porcentaje * 100))% logrado).",
        ]
        if let p = perfil {
            partes.append("Perfil: \(p.fitnessLevelRaw), ritmo habitual \(p.formattedPace), corre \(p.weeklyRuns ?? 2) veces/semana.")
            if let v = p.vo2Max { partes.append("VO2max: \(Int(v)).") }
            if let w = p.weeklyRuns { partes.append("Corridas semanales: \(w).") }
        }
        if stats.planGananciaElevacionM > 0 {
            partes.append("Desnivel acumulado: \(stats.planGananciaElevacionM) m.")
        }
        return partes.joined(separator: " ")
    }

    private func fallback(stats: RunStats) -> ResumenRunIA {
        if stats.completado {
            return ResumenRunIA(
                mensaje: "¡Completaste los \(String(format: "%.1f", stats.planDistanciaKm)) km en \(stats.elapsedFormatted)! Eso es un gran logro.",
                protips: [
                    "Mantén la consistencia — correr \(max((stats.elapsedSeconds / 60) - 5, 1)) min más la próxima sesión es un buen incremento.",
                    "Tu ritmo de hoy fue \(stats.ritmoStr) — apunta a mantenerlo en tu próxima corrida.",
                    "Hidratación post-corrida: toma al menos 500ml en los siguientes 30 min."
                ]
            )
        } else {
            return ResumenRunIA(
                mensaje: "Corriste \(String(format: "%.2f", stats.distanciaRecorridaKm)) km de \(String(format: "%.1f", stats.planDistanciaKm)) km — un \(Int(stats.porcentaje * 100))% del objetivo. Cada kilómetro cuenta.",
                protips: [
                    "Aumenta la distancia gradualmente: 10% más por semana es el estándar para evitar lesiones.",
                    "Tu ritmo de \(stats.ritmoStr) es sostenible — úsalo como base para la próxima corrida.",
                    "Considera correr los primeros 2km más lento para conservar energía para el final."
                ]
            )
        }
    }
}

// MARK: - View

struct RunEndSummaryView: View {
    @Environment(\.currentUserProfile) private var perfil
    @Environment(\.dismiss) private var dismiss

    @State private var resumenService = ResumenService()

    let stats: RunStats
    let onClose: () -> Void

    var body: some View {
        ZStack {
            TrazoColors.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: TrazoSpacing.xl) {
                    encabezado
                    statsGrid
                    if !stats.completado { barraProgreso }
                    tipsSection
                    botonCerrar
                }
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.top, TrazoSpacing.xxxl)
                .padding(.bottom, TrazoSpacing.xxxl)
            }
        }
        .task { await resumenService.generar(stats: stats, perfil: perfil) }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        VStack(spacing: TrazoSpacing.md) {
            Text(stats.completado ? "🏆" : "💪")
                .font(.system(size: 56))
            switch resumenService.estado {
            case .cargando:
                VStack(spacing: TrazoSpacing.sm) {
                    ProgressView().tint(TrazoColors.routeTeal)
                    Text("Analizando tu corrida...")
                        .font(TrazoTypography.body())
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            case .listo(let r):
                Text(stats.completado ? "¡Lo lograste!" : "¡Buen esfuerzo!")
                    .font(TrazoTypography.largeTitle())
                    .foregroundStyle(TrazoColors.textPrimary)
                Text(r.mensaje)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)
                    .multilineTextAlignment(.center)
            case .error:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats

    private var statsGrid: some View {
        HStack(spacing: TrazoSpacing.md) {
            statCard(valor: String(format: "%.2f", stats.distanciaRecorridaKm), unidad: "KM", label: "Corriste")
            statCard(valor: stats.elapsedFormatted, unidad: "", label: "Tiempo")
            statCard(valor: stats.ritmoStr.components(separatedBy: " ").first ?? stats.ritmoStr, unidad: "/km", label: "Ritmo")
        }
        .frame(maxWidth: .infinity)

    }

    private func statCard(valor: String, unidad: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(valor)
                    .font(TrazoTypography.statValue())
                    .foregroundStyle(TrazoColors.textPrimary)
                    .minimumScaleFactor(0.7)
                if !unidad.isEmpty {
                    Text(unidad)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }
            Text(label)
                .font(TrazoTypography.statLabel())
                .foregroundStyle(TrazoColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
    }

    // MARK: - Barra de progreso

    private var barraProgreso: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            HStack {
                Text("Progreso de la ruta")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
                Spacer()
                Text(String(format: "%.0f%%", stats.porcentaje * 100))
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(TrazoColors.surface).frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(TrazoColors.routeTeal)
                        .frame(width: geo.size.width * stats.porcentaje, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Tips

    @ViewBuilder
    private var tipsSection: some View {
        switch resumenService.estado {
        case .cargando:
            HStack(spacing: TrazoSpacing.sm) {
                ProgressView().tint(TrazoColors.routeTeal)
                Text("Generando pro tips personalizados...")
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(TrazoSpacing.xl)
        case .listo(let r):
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                Text("Pro Tips")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
                ForEach(Array(r.protips.enumerated()), id: \.offset) { _, tip in
                    tipCard(texto: tip)
                }
            }
        case .error:
            EmptyView()
        }
    }

    private func tipCard(texto: String) -> some View {
        HStack(alignment: .top, spacing: TrazoSpacing.md) {
            Image(systemName: "lightbulb.fill")
                .font(.caption)
                .foregroundStyle(TrazoColors.accentOrange)
                .padding(.top, 2)
            Text(texto)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)
        }
        .padding(TrazoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
    }

    // MARK: - Botón

    private var botonCerrar: some View {
        TrazoButton(title: "Cerrar") {
            dismiss()
            onClose()
        }
    }
}
