import CoreLocation
import MapKit
import SwiftUI

struct AITrazoSheet: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss

    enum ModoRuta: String, CaseIterable {
        case circular = "Ida y vuelta"
        case soloIda  = "Solo ida"
    }

    enum EstadoRutas {
        case inactivo
        case interpretando
        case generando
        case opciones([RoutePlan])
        case error(String)
    }

    @State private var aiService = AITrazoService()
    @State private var estadoRutas: EstadoRutas = .inactivo
    @State private var promptText = ""
    @State private var modoRuta: ModoRuta = .circular
    @State private var routeError: String?
    @FocusState private var inputFocused: Bool

    let userLocation: CLLocationCoordinate2D?
    let onRouteReady: (RoutePlan) -> Void

    private let sugerencias = [
        "5km tranquilo", "algo exigente hoy",
        "corto para activarme", "10km de fondo", "sorpréndeme"
    ]

    private let bearings: [Double] = [45, 165, 285]   // NE, S-SE, NO

    var body: some View {
        VStack(spacing: 0) {
            encabezado
            Divider().opacity(0.15)
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    modoPickerSection
                    inputSection
                    if case .inactivo = estadoRutas { sugerenciasSection }
                    estadoSection
                }
                .padding(.horizontal, TrazoSpacing.xl)
                .padding(.top, TrazoSpacing.xl)
                .padding(.bottom, TrazoSpacing.xxxl)
            }
            if case .opciones = estadoRutas { } else {
                botonPrincipal
                    .padding(.horizontal, TrazoSpacing.xl)
                    .padding(.bottom, TrazoSpacing.xl)
            }
        }
        .background(TrazoColors.background)
        .alert("No se pudo crear el Trazo", isPresented: .init(
            get: { routeError != nil },
            set: { if !$0 { routeError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: { Text(routeError ?? "") }
    }

    // MARK: - Modo picker

    private var modoPickerSection: some View {
        Picker("Tipo", selection: $modoRuta) {
            ForEach(ModoRuta.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .onChange(of: modoRuta) { _, _ in estadoRutas = .inactivo; aiService.reiniciar() }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack {
            HStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "sparkles").foregroundStyle(TrazoColors.accentOrange)
                Text("Trazo IA").font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(TrazoColors.textSecondary)
            }
        }
        .padding(.horizontal, TrazoSpacing.xl)
        .padding(.vertical, TrazoSpacing.lg)
    }

    // MARK: - Input

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text("¿Qué quieres correr hoy?")
                .font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
            TextField("Cuéntame tu plan...", text: $promptText, axis: .vertical)
                .font(TrazoTypography.body()).foregroundStyle(TrazoColors.textPrimary)
                .lineLimit(2...4)
                .padding(TrazoSpacing.lg)
                .background(TrazoColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                .focused($inputFocused)
                .disabled(isOcupado)
                .onAppear { inputFocused = true }
                .onChange(of: promptText) { _, _ in
                    if case .error = estadoRutas { estadoRutas = .inactivo; aiService.reiniciar() }
                }
        }
    }

    // MARK: - Sugerencias

    private var sugerenciasSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text("Sugerencias").font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: TrazoSpacing.sm)], spacing: TrazoSpacing.sm) {
                ForEach(sugerencias, id: \.self) { s in
                    Button { promptText = s; inputFocused = false } label: {
                        Text(s).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.routeTeal)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, TrazoSpacing.md).padding(.vertical, TrazoSpacing.sm)
                            .background(TrazoColors.routeTeal.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Estado rutas

    @ViewBuilder
    private var estadoSection: some View {
        switch estadoRutas {
        case .inactivo:
            EmptyView()
        case .interpretando:
            spinnerRow("Interpretando tu solicitud...")
        case .generando:
            spinnerRow("Generando 3 opciones de Trazo...")
        case .opciones(let planes):
            opcionesSection(planes)
        case .error(let msg):
            Text(msg).font(TrazoTypography.caption()).foregroundStyle(.red.opacity(0.8))
        }
    }

    private func spinnerRow(_ texto: String) -> some View {
        HStack(spacing: TrazoSpacing.md) {
            ProgressView().tint(TrazoColors.routeTeal)
            Text(texto).font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(TrazoSpacing.xl)
    }

    // MARK: - Opciones de ruta

    private func opcionesSection(_ planes: [RoutePlan]) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Elige tu Trazo").font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
            ForEach(Array(planes.enumerated()), id: \.element.id) { idx, plan in
                routeOptionCard(plan: plan, bearing: bearings[safe: idx] ?? Double(idx * 90))
            }
        }
    }

    private func routeOptionCard(plan: RoutePlan, bearing: Double) -> some View {
        Button {
            dismiss()
            onRouteReady(plan)
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Mini mapa
                miniMapView(plan: plan)
                // Stats
                VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                    Text("Hacia el \(nombreRumbo(bearing))")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)
                    HStack(spacing: TrazoSpacing.lg) {
                        statPill(icon: "figure.run", value: String(format: "%.1f km", plan.distanceKm))
                        statPill(icon: "clock", value: "\(plan.estimatedMinutes) min")
                        if plan.gananciaElevacionM > 0 {
                            statPill(icon: "arrow.up.right", value: "\(plan.gananciaElevacionM)m")
                        }
                    }
                    Text(plan.desnivel)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(.white)
                        .padding(.horizontal, TrazoSpacing.sm).padding(.vertical, 3)
                        .background(colorDificultad(plan.desnivel))
                        .clipShape(Capsule())
                }
                .padding(TrazoSpacing.lg)
            }
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous)
                    .strokeBorder(TrazoColors.routeTeal.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func miniMapView(plan: RoutePlan) -> some View {
        let camPos = MapCameraFitter.cameraPosition(
            for: plan.coordinates,
            mapSize: CGSize(width: 320, height: 110),
            edgePadding: UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        )
        return Map(position: .constant(camPos)) {
            MapPolyline(coordinates: plan.coordinates)
                .stroke(TrazoColors.routeTeal, lineWidth: 3)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { }
        .frame(height: 110)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: TrazoRadius.md,
            topTrailingRadius: TrazoRadius.md
        ))
        .allowsHitTesting(false)
    }

    private func statPill(icon: String, value: String) -> some View {
        HStack(spacing: TrazoSpacing.xs) {
            Image(systemName: icon).font(.caption).foregroundStyle(TrazoColors.textSecondary)
            Text(value).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textPrimary)
        }
    }

    private func colorDificultad(_ d: String) -> Color {
        switch d { case "Exigente": .red.opacity(0.7); case "Moderada": .orange.opacity(0.7); default: .green.opacity(0.7) }
    }

    private func nombreRumbo(_ grados: Double) -> String {
        switch grados {
        case 0..<22.5, 337.5...360: return "Norte"
        case 22.5..<67.5:  return "Noreste"
        case 67.5..<112.5: return "Este"
        case 112.5..<157.5: return "Sureste"
        case 157.5..<202.5: return "Sur"
        case 202.5..<247.5: return "Suroeste"
        case 247.5..<292.5: return "Oeste"
        default:            return "Noroeste"
        }
    }

    // MARK: - Botón principal

    @ViewBuilder
    private var botonPrincipal: some View {
        switch estadoRutas {
        case .inactivo, .error:
            TrazoButton(
                title: "Generar opciones",
                isEnabled: !promptText.trimmingCharacters(in: .whitespaces).isEmpty
            ) {
                inputFocused = false
                Task { await generarOpciones() }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Lógica

    private var isOcupado: Bool {
        switch estadoRutas {
        case .interpretando, .generando: true
        default: false
        }
    }

    private func generarOpciones() async {
        guard let loc = userLocation else {
            estadoRutas = .error("No pudimos obtener tu ubicación.")
            return
        }

        estadoRutas = .interpretando
        await aiService.interpretar(promptText, perfil: profile)

        guard case .listo(let intent) = aiService.estado else {
            if case .error(let msg) = aiService.estado { estadoRutas = .error(msg) }
            return
        }

        estadoRutas = .generando

        let planes = await withTaskGroup(of: RoutePlan?.self) { group in
            for bearing in bearings {
                group.addTask {
                    switch self.modoRuta {
                    case .circular:
                        return try? await RouteCalculator.calculateCircularWithBearing(
                            distanciaKm: intent.distanciaKm, bearing: bearing, from: loc, profile: self.profile)
                    case .soloIda:
                        return try? await RouteCalculator.calculateOneWayWithBearing(
                            distanciaKm: intent.distanciaKm, bearing: bearing, from: loc, profile: self.profile)
                    }
                }
            }
            var r: [RoutePlan] = []
            for await p in group { if let p { r.append(p) } }
            return r
        }

        if planes.isEmpty {
            estadoRutas = .error("No se encontraron rutas disponibles. Intenta con otra distancia.")
        } else {
            estadoRutas = .opciones(planes)
        }
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
