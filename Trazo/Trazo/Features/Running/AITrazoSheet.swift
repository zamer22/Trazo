import CoreLocation
import SwiftUI

struct AITrazoSheet: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss

    @State private var aiService = AITrazoService()
    @State private var promptText = ""
    @State private var isCreatingRoute = false
    @State private var routeError: String?
    @FocusState private var inputFocused: Bool

    let userLocation: CLLocationCoordinate2D?
    let onRouteReady: (RoutePlan) -> Void

    private let sugerencias = [
        "5km tranquilo",
        "algo exigente hoy",
        "corto para activarme",
        "10km de fondo",
        "sorpréndeme"
    ]

    var body: some View {
        VStack(spacing: 0) {
            encabezado
            Divider().opacity(0.15)
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    inputSection
                    if case .inactivo = aiService.estado {
                        sugerenciasSection
                    }
                    estadoSection
                }
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.top, TrazoSpacing.xl)
                .padding(.bottom, TrazoSpacing.xxxl)
            }
            botonPrincipal
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.bottom, TrazoSpacing.xl)
        }
        .background(TrazoColors.background)
        .alert("No se pudo crear el Trazo", isPresented: .init(
            get: { routeError != nil },
            set: { if !$0 { routeError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(routeError ?? "")
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack {
            HStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "sparkles")
                    .foregroundStyle(TrazoColors.accentOrange)
                Text("Trazo IA")
                    .font(TrazoTypography.title())
                    .foregroundStyle(TrazoColors.textPrimary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(TrazoColors.textSecondary)
            }
        }
        .padding(.horizontal, TrazoSpacing.xl)
        .padding(.vertical, TrazoSpacing.lg)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text("¿Qué quieres correr hoy?")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)
            TextField("Cuéntame tu plan...", text: $promptText, axis: .vertical)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)
                .lineLimit(2...4)
                .padding(TrazoSpacing.lg)
                .background(TrazoColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                .focused($inputFocused)
                .disabled(isInterpreting || isCreatingRoute)
                .onAppear { inputFocused = true }
                .onChange(of: promptText) { _, _ in
                    if case .error = aiService.estado { aiService.reiniciar() }
                    if case .listo = aiService.estado { aiService.reiniciar() }
                }
        }
    }

    // MARK: - Sugerencias

    private var sugerenciasSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text("Sugerencias")
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 110), spacing: TrazoSpacing.sm)],
                spacing: TrazoSpacing.sm
            ) {
                ForEach(sugerencias, id: \.self) { sugerencia in
                    Button {
                        promptText = sugerencia
                        inputFocused = false
                    } label: {
                        Text(sugerencia)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.routeTeal)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, TrazoSpacing.md)
                            .padding(.vertical, TrazoSpacing.sm)
                            .background(TrazoColors.routeTeal.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Estado IA

    @ViewBuilder
    private var estadoSection: some View {
        switch aiService.estado {
        case .inactivo:
            EmptyView()
        case .procesando:
            HStack(spacing: TrazoSpacing.md) {
                ProgressView().tint(TrazoColors.routeTeal)
                Text("Interpretando tu solicitud...")
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(TrazoSpacing.xl)
        case .listo(let intent):
            intentCard(intent)
        case .error(let msg):
            Text(msg)
                .font(TrazoTypography.caption())
                .foregroundStyle(.red.opacity(0.8))
        }
    }

    private func intentCard(_ intent: IntentTrazo) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.lg) {
            HStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(TrazoColors.routeTeal)
                Text(intent.etiqueta)
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
            }
            HStack(spacing: TrazoSpacing.xl) {
                statPill(
                    icon: "figure.run",
                    value: String(format: "%.1f km", intent.distanciaKm)
                )
                statPill(
                    icon: iconForDificultad(intent.dificultad),
                    value: intent.dificultad.capitalized
                )
            }
            if isCreatingRoute {
                HStack(spacing: TrazoSpacing.sm) {
                    ProgressView().tint(TrazoColors.routeTeal).scaleEffect(0.8)
                    Text("Calculando tu ruta...")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TrazoSpacing.xl)
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous)
                .strokeBorder(TrazoColors.routeTeal.opacity(0.25), lineWidth: 1)
        )
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: TrazoSpacing.xs) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(TrazoColors.textSecondary)
            Text(value)
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textPrimary)
        }
    }

    private func iconForDificultad(_ d: String) -> String {
        switch d.lowercased() {
        case "exigente": "flame.fill"
        case "moderada": "arrow.up.forward"
        default: "leaf.fill"
        }
    }

    // MARK: - Botón principal

    @ViewBuilder
    private var botonPrincipal: some View {
        if case .listo(let intent) = aiService.estado {
            TrazoButton(title: "Crear este Trazo", isEnabled: !isCreatingRoute) {
                Task { await crearTrazo(intent) }
            }
        } else {
            TrazoButton(
                title: "Generar Trazo",
                isEnabled: !promptText.trimmingCharacters(in: .whitespaces).isEmpty && !isInterpreting
            ) {
                inputFocused = false
                Task { await aiService.interpretar(promptText, perfil: profile) }
            }
        }
    }

    // MARK: - Helpers

    private var isInterpreting: Bool {
        if case .procesando = aiService.estado { return true }
        return false
    }

    private func crearTrazo(_ intent: IntentTrazo) async {
        guard let loc = userLocation else {
            routeError = "No pudimos obtener tu ubicación."
            return
        }
        isCreatingRoute = true
        defer { isCreatingRoute = false }
        do {
            let plan = try await RouteCalculator.calculateCircular(
                distanciaKm: intent.distanciaKm,
                from: loc,
                profile: profile
            )
            dismiss()
            onRouteReady(plan)
        } catch {
            routeError = "No se encontró un Trazo disponible. Intenta con otra distancia."
        }
    }
}
