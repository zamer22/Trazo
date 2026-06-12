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
    @Guide(description: "Mensaje de 2 oraciones en español cotidiano. Si completó: celebra con entusiasmo real mencionando la distancia y tiempo. Si no completó: alienta positivamente. SIN términos médicos, como si lo dijera un amigo corredor.")
    var mensaje: String

    @Guide(description: "Lista de exactamente 3 consejos prácticos en lenguaje simple que cualquier persona entiende. Ejemplos: 'La próxima vez intenta salir 10 minutos antes para calentar', 'Bebe agua en cuanto termines, el cuerpo lo necesita'. SIN VO₂ máx, sin zonas cardíacas, sin términos técnicos.")
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
                instructions: "Eres un coach de running amigo que habla de manera cercana y simple. NUNCA uses términos médicos como VO₂ máx, zona cardíaca, lactato, ni porcentajes de FC. Habla como: 'tu resistencia está mejorando', 'el cuerpo respondió bien', 'vas a fondo'. Los consejos deben ser prácticos y cotidianos."
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
    @State private var aparecer = false

    let stats: RunStats
    let onClose: () -> Void

    var body: some View {
        ZStack {
            TrazoColors.background.ignoresSafeArea()
            VStack(spacing: 0) {
                heroSection
                ScrollView(showsIndicators: false) {
                    VStack(spacing: TrazoSpacing.xl) {
                        statsRow
                        if !stats.completado { barraProgreso }
                        aiMensajeSection
                        tipsSection
                        botonCerrar
                    }
                    .padding(.horizontal, TrazoSpacing.xl)
                    .padding(.top, TrazoSpacing.xl)
                    .padding(.bottom, 60)
                }
            }
        }
        .task { await resumenService.generar(stats: stats, perfil: perfil) }
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(0.1)) { aparecer = true }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: stats.completado
                    ? [TrazoColors.routeTeal, TrazoColors.routeTeal.opacity(0.75)]
                    : [TrazoColors.accentOrange, TrazoColors.accentOrange.opacity(0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: TrazoSpacing.md) {
                Image(systemName: stats.completado ? "checkmark.circle.fill" : "figure.run.circle.fill")
                    .font(.system(size: 52, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .scaleEffect(aparecer ? 1 : 0.5)
                    .opacity(aparecer ? 1 : 0)
                Text(stats.completado ? "¡Ruta completada!" : "¡Buen esfuerzo!")
                    .font(TrazoTypography.largeTitle())
                    .foregroundStyle(.white)
                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(String(format: "%.2f", stats.distanciaRecorridaKm))
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                    Text("km")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(aparecer ? 1 : 0)
                .offset(y: aparecer ? 0 : 20)
            }
            .padding(.top, 56)
            .padding(.bottom, TrazoSpacing.xxxl)
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: .top)
        .frame(maxHeight: 280)
    }

    // MARK: - Stats fila

    private var statsRow: some View {
        HStack(spacing: TrazoSpacing.md) {
            miniStat(valor: stats.elapsedFormatted, label: "Tiempo")
            miniStat(valor: stats.ritmoStr.components(separatedBy: " ").first ?? "--", label: "Ritmo /km")
            miniStat(valor: "\(stats.calorias)", label: "Calorías")
        }
    }

    private func miniStat(valor: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(TrazoTypography.statValue())
                .foregroundStyle(TrazoColors.textPrimary)
                .minimumScaleFactor(0.6)
                .monospacedDigit()
            Text(label)
                .font(TrazoTypography.statLabel())
                .foregroundStyle(TrazoColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TrazoSpacing.lg)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    // MARK: - AI mensaje

    @ViewBuilder
    private var aiMensajeSection: some View {
        switch resumenService.estado {
        case .cargando:
            HStack(spacing: TrazoSpacing.md) {
                ProgressView().tint(TrazoColors.routeTeal)
                Text("Tu coach está analizando la corrida...")
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        case .listo(let r):
            HStack(alignment: .top, spacing: TrazoSpacing.md) {
                Image(systemName: "person.fill.checkmark")
                    .font(.body)
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(stats.completado ? TrazoColors.routeTeal : TrazoColors.accentOrange)
                    .clipShape(Circle())
                Text(r.mensaje)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        case .error:
            EmptyView()
        }
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
                    .font(TrazoTypography.caption().weight(.semibold))
                    .foregroundStyle(TrazoColors.routeTeal)
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
        case .listo(let r):
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                Label("Consejos para tu próxima corrida", systemImage: "lightbulb.fill")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
                ForEach(Array(r.protips.enumerated()), id: \.offset) { idx, tip in
                    tipCard(numero: idx + 1, texto: tip)
                }
            }
        default:
            EmptyView()
        }
    }

    private func tipCard(numero: Int, texto: String) -> some View {
        HStack(alignment: .top, spacing: TrazoSpacing.md) {
            Text("\(numero)")
                .font(TrazoTypography.caption().weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(TrazoColors.accentOrange)
                .clipShape(Circle())
                .padding(.top, 1)
            Text(texto)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(TrazoSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    // MARK: - Botón

    private var botonCerrar: some View {
        TrazoButton(title: "Cerrar") {
            dismiss()
            onClose()
        }
    }
}
