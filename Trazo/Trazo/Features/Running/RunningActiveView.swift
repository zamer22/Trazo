import CoreLocation
import MapKit
import Supabase
import SwiftUI

struct RunningActiveView: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss
    @AppStorage("voiceNavigationEnabled") private var voiceNavigationEnabled = true

    @State private var locationManager = LocationManager()
    @State private var sessionTracker: RunningSessionTracker
    @State private var pines: [PinAdvertencia] = []
    @State private var isReportando = false
    @State private var pinesEliminados: Set<UUID> = []
    @State private var statsFinales: RunStats?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var barraStatsHeight: CGFloat = 160
    @State private var siguiendoUsuario = true
    @State private var actualizandoCamara = false
    @State private var mostrarConfirmarFinalizar = false
    @State private var pollingClubTask: Task<Void, Never>?
    @State private var finalizadoPorOtro = false

    let plan: RoutePlan
    let clubSesionId: UUID?
    private let voiceNav: VoiceNavigationService

    init(plan: RoutePlan, clubSesionId: UUID? = nil) {
        self.plan = plan
        self.clubSesionId = clubSesionId
        self._sessionTracker = State(initialValue: RunningSessionTracker(plan: plan))
        self.voiceNav = VoiceNavigationService(coordenadas: plan.coordinates)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mapaActivo
                .ignoresSafeArea()

            // Botón de cámara flotante sobre el panel
            botonCamara
                .padding(.trailing, TrazoSpacing.xl)
                .padding(.bottom, barraStatsHeight + TrazoSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .trailing)

            panelStats
                .background {
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { barraStatsHeight = geo.size.height }
                            .onChange(of: geo.size.height) { _, h in barraStatsHeight = h }
                    }
                }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .overlay(alignment: .top) { barraTop }
        .overlay(alignment: .top) {
            if sessionTracker.estaFueraDeRuta {
                futeraDeRutaBanner
                    .padding(.top, 100)
            }
        }
        .sheet(isPresented: $isReportando) {
            PinReporteSheet(userLocation: locationManager.userLocation, userId: profile?.id) { tipo, coord in
                Task { await agregarPinLocal(tipo: tipo, coord: coord) }
            }
            .presentationDetents([.medium, .large])
            .presentationCornerRadius(TrazoRadius.lg)
            .presentationBackground(TrazoColors.background)
        }
        .fullScreenCover(item: $statsFinales, onDismiss: { dismiss() }) { stats in
            RunEndSummaryView(stats: stats, onClose: { dismiss() })
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            sessionTracker.iniciar()
            if voiceNavigationEnabled { voiceNav.iniciarRuta() }
            Task { await cargarPines() }
            iniciarPollingClubSesion()
        }
        .onDisappear {
            sessionTracker.pausar()
            locationManager.stopUpdating()
            voiceNav.detener()
            pollingClubTask?.cancel()
        }
        .onChange(of: locationManager.userLocation?.latitude) { _, _ in
            guard let loc = locationManager.userLocation else { return }
            seguirConCamara(loc)
            sessionTracker.actualizarUbicacion(loc)
            if voiceNavigationEnabled {
                voiceNav.actualizarPosicion(indiceActual: sessionTracker.indiceMasCercano)
            }
            verificarPinesCercanos(loc)
        }
        .onChange(of: sessionTracker.estaFueraDeRuta) { _, fueraDeRuta in
            if fueraDeRuta && voiceNavigationEnabled { voiceNav.anunciarFueraDeRuta() }
        }
        .onChange(of: locationManager.lastFullLocation?.timestamp) { _, _ in
            guard let loc = locationManager.lastFullLocation else { return }
            sessionTracker.actualizarVelocidad(loc)
        }
    }

    // MARK: - Mapa

    private var mapaActivo: some View {
        Map(position: $cameraPosition) {
            // Tramo restante (brillante, alto contraste)
            if sessionTracker.coordenadasRestantes.count > 1 {
                MapPolyline(coordinates: sessionTracker.coordenadasRestantes)
                    .stroke(TrazoColors.accentOrange, lineWidth: 7)
            } else {
                MapPolyline(coordinates: plan.coordinates)
                    .stroke(TrazoColors.accentOrange, lineWidth: 7)
            }
            // Tramo cubierto (teal sólido)
            if sessionTracker.coordenadasCubiertas.count > 1 {
                MapPolyline(coordinates: sessionTracker.coordenadasCubiertas)
                    .stroke(TrazoColors.routeTeal, lineWidth: 7)
            }
            // Posición del usuario
            if let loc = locationManager.userLocation {
                Annotation("Tú", coordinate: loc, anchor: .center) {
                    ZStack {
                        Circle()
                            .fill(TrazoColors.routeTeal.opacity(0.25))
                            .frame(width: 34, height: 34)
                        Circle()
                            .fill(TrazoColors.routeTeal)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    }
                }
            }
            // Pines de advertencia
            ForEach(pines) { pin in
                Annotation(pin.etiqueta, coordinate: pin.coordinate, anchor: .bottom) {
                    PinMapAnnotation(pin: pin) {
                        eliminarPinInmediato(pin)
                    }
                }
            }
            // Pin de destino
            Annotation(plan.destinationName, coordinate: plan.destinationCoordinate, anchor: .bottom) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(TrazoColors.accentOrange)
                            .frame(width: 34, height: 34)
                            .shadow(color: TrazoColors.accentOrange.opacity(0.5), radius: 6, y: 3)
                        Image(systemName: "flag.checkered")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Triangle()
                        .fill(TrazoColors.accentOrange)
                        .frame(width: 10, height: 6)
                }
            }
        }
        .mapStyle(.standard(elevation: .automatic, pointsOfInterest: .excludingAll))
        .mapControls { MapScaleView() }
        .onMapCameraChange { _ in
            if !actualizandoCamara { siguiendoUsuario = false }
        }
    }

    // MARK: - Barra superior

    private var barraTop: some View {
        HStack {
            Button {
                mostrarConfirmarFinalizar = true
            } label: {
                HStack(spacing: TrazoSpacing.xs) {
                    Image(systemName: "stop.fill")
                        .font(.caption.weight(.bold))
                    Text("Finalizar")
                        .font(TrazoTypography.caption())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, TrazoSpacing.md)
                .padding(.vertical, TrazoSpacing.sm)
                .background(Color.red.opacity(0.88))
                .clipShape(Capsule())
                .shadow(color: Color.red.opacity(0.4), radius: 6, y: 2)
            }
            .accessibilityLabel("Finalizar corrida")
            .accessibilityHint("Detiene la sesión y muestra el resumen de tu corrida")
            .confirmationDialog("¿Finalizar corrida?", isPresented: $mostrarConfirmarFinalizar, titleVisibility: .visible) {
                if clubSesionId != nil {
                    Button("Finalizar solo para mí", role: .destructive) {
                        sessionTracker.pausar()
                        finalizarConStats()
                    }
                    Button("Finalizar para todos", role: .destructive) {
                        sessionTracker.pausar()
                        Task { await finalizarParaTodos() }
                    }
                } else {
                    Button("Finalizar", role: .destructive) {
                        sessionTracker.pausar()
                        finalizarConStats()
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                if clubSesionId != nil {
                    Text("Puedes salir solo tú o terminar la corrida del club para todos los participantes.")
                } else {
                    Text("Se guardará tu progreso hasta este punto.")
                }
            }
            Spacer()
            HStack(spacing: TrazoSpacing.xs) {
                Image(systemName: "figure.run")
                    .font(.caption.weight(.semibold))
                Text(sessionTracker.elapsedFormatted)
                    .font(TrazoTypography.headline())
                    .monospacedDigit()
            }
            .foregroundStyle(TrazoColors.textPrimary)
            .padding(.horizontal, TrazoSpacing.md)
            .padding(.vertical, TrazoSpacing.sm)
            .background(.ultraThinMaterial)
            .background(TrazoColors.elevated.opacity(0.85))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.top, TrazoSpacing.xl)
    }

    // MARK: - Botón cámara

    private var botonCamara: some View {
        VStack(spacing: TrazoSpacing.sm) {
            if !siguiendoUsuario {
                Button {
                    siguiendoUsuario = true
                    if let loc = locationManager.userLocation { seguirConCamara(loc) }
                } label: {
                    Image(systemName: "location.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(TrazoColors.routeTeal)
                        .clipShape(Circle())
                        .shadow(color: TrazoColors.routeTeal.opacity(0.5), radius: 6, y: 2)
                }
                .transition(.scale.combined(with: .opacity))
            }
            Button {
                isReportando = true
            } label: {
                Image(systemName: "camera.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(TrazoColors.accentOrange)
                    .clipShape(Circle())
                    .shadow(color: TrazoColors.accentOrange.opacity(0.5), radius: 8, y: 3)
            }
            .accessibilityLabel("Reportar problema")
            .accessibilityHint("Abre la cámara para fotografiar y reportar un obstáculo o peligro en la ruta")
        }
        .animation(.spring(duration: 0.3), value: siguiendoUsuario)
    }

    // MARK: - Panel de stats

    private var panelStats: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                statItem(valor: String(format: "%.2f", sessionTracker.distanciaRecorridaKm), unidad: "KM", label: "Recorrido")
                Divider().frame(height: 40).opacity(0.2)
                statItem(valor: sessionTracker.elapsedFormatted, unidad: "", label: "Tiempo")
                Divider().frame(height: 40).opacity(0.2)
                statItem(valor: "\(sessionTracker.tiempoRestanteMin)", unidad: "min", label: "Restante")
            }
            .padding(.top, TrazoSpacing.md)

            Divider().opacity(0.15).padding(.horizontal, TrazoSpacing.xl).padding(.top, TrazoSpacing.sm)

            HStack(spacing: 0) {
                statItem(valor: sessionTracker.ritmoActualStr.components(separatedBy: " ").first ?? "--:--", unidad: "/km", label: "Ritmo")
                Divider().frame(height: 40).opacity(0.2)
                statItem(valor: "\(sessionTracker.caloriasQuemadas)", unidad: "Cal", label: "Calorías")
                Divider().frame(height: 40).opacity(0.2)
                statItem(valor: String(format: "%.0f%%", sessionTracker.porcentajeCompletado * 100), unidad: "", label: "Completado")
            }
            .padding(.vertical, TrazoSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                UnevenRoundedRectangle(topLeadingRadius: TrazoRadius.lg, topTrailingRadius: TrazoRadius.lg)
                    .fill(.ultraThinMaterial)
                UnevenRoundedRectangle(topLeadingRadius: TrazoRadius.lg, topTrailingRadius: TrazoRadius.lg)
                    .fill(Color.black.opacity(0.55))
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .clipped()
    }

    private func statItem(valor: String, unidad: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(valor)
                    .font(TrazoTypography.statValue())
                    .foregroundStyle(.white)
                    .monospacedDigit()
                if !unidad.isEmpty {
                    Text(unidad)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            Text(label)
                .font(TrazoTypography.statLabel())
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Fuera de ruta

    private var futeraDeRutaBanner: some View {
        HStack(spacing: TrazoSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("¡Te saliste de la ruta! Regresa al camino marcado.")
                .font(TrazoTypography.caption())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
        .background(Color.red.opacity(0.9))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(duration: 0.4), value: sessionTracker.estaFueraDeRuta)
    }

    // MARK: - Helpers

    private func seguirConCamara(_ loc: CLLocationCoordinate2D) {
        guard siguiendoUsuario else { return }
        let proximaCoordenada = sessionTracker.coordenadasRestantes.first ?? plan.coordinates.first ?? loc
        let rumbo = calcularRumbo(desde: loc, hacia: proximaCoordenada)
        actualizandoCamara = true
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: loc,
                distance: 250,
                heading: rumbo,
                pitch: 0
            ))
        }
        Task {
            try? await Task.sleep(for: .milliseconds(700))
            actualizandoCamara = false
        }
    }

    private func calcularRumbo(desde: CLLocationCoordinate2D, hacia: CLLocationCoordinate2D) -> Double {
        let lat1 = desde.latitude * .pi / 180
        let lat2 = hacia.latitude * .pi / 180
        let dLon = (hacia.longitude - desde.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    private func cargarPines() async {
        guard let loc = locationManager.userLocation else { return }
        pines = (try? await PinAdvertenciaService.fetchActivos(cerca: loc, radioKm: 3.0)) ?? []
    }

    private func agregarPinLocal(tipo: String, coord: CLLocationCoordinate2D) async {
        // Recarga desde Supabase para tener el id real
        await cargarPines()
    }

    private func finalizarConStats(completado: Bool? = nil) {
        let pct = sessionTracker.porcentajeCompletado
        let realCompletado = completado ?? (pct >= 0.95)
        if realCompletado && voiceNavigationEnabled { voiceNav.anunciarCompletada() }
        statsFinales = RunStats(
            distanciaRecorridaKm: sessionTracker.distanciaRecorridaKm,
            elapsedSeconds: sessionTracker.elapsedSeconds,
            ritmoStr: sessionTracker.ritmoActualStr,
            calorias: sessionTracker.caloriasQuemadas,
            completado: realCompletado,
            planDistanciaKm: plan.distanceKm,
            planGananciaElevacionM: plan.gananciaElevacionM
        )
    }

    private func verificarPinesCercanos(_ loc: CLLocationCoordinate2D) {
        let locUsuario = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        for pin in pines {
            let locPin = CLLocation(latitude: pin.latitud, longitude: pin.longitud)
            let distancia = locUsuario.distance(from: locPin)
            if distancia < 25 {
                eliminarPinInmediato(pin)
            } else if distancia < 80 && voiceNavigationEnabled {
                voiceNav.anunciarPinCercano(pin.etiqueta)
            }
        }
    }

    private func iniciarPollingClubSesion() {
        guard let sesionId = clubSesionId else { return }
        pollingClubTask?.cancel()
        pollingClubTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                struct EstadoRow: Decodable { let estado: String }
                let row: EstadoRow? = try? await SupabaseService.client
                    .from("sesiones_club")
                    .select("estado")
                    .eq("id", value: sesionId.uuidString)
                    .single().execute().value
                if let estado = row?.estado, estado == "finalizada" {
                    if statsFinales == nil {
                        finalizadoPorOtro = true
                        sessionTracker.pausar()
                        finalizarConStats()
                    }
                    break
                }
            }
        }
    }

    private func finalizarParaTodos() async {
        guard let sesionId = clubSesionId else { return }
        struct Params: Encodable { let p_sesion_id: UUID }
        do {
            try await SupabaseService.client
                .rpc("finalizar_corrida_club", params: Params(p_sesion_id: sesionId))
                .execute()
        } catch {
            // Fallback: intentar el update directo (por si el RPC no está desplegado)
            struct Update: Encodable { let estado: String }
            try? await SupabaseService.client
                .from("sesiones_club")
                .update(Update(estado: "finalizada"))
                .eq("id", value: sesionId.uuidString)
                .execute()
        }
        finalizarConStats()
    }

    private func eliminarPinInmediato(_ pin: PinAdvertencia) {
        guard !pinesEliminados.contains(pin.id) else { return }
        pinesEliminados.insert(pin.id)
        withAnimation(.easeOut(duration: 0.25)) {
            pines.removeAll { $0.id == pin.id }
        }
        Task { try? await PinAdvertenciaService.votarResuelto(pinId: pin.id) }
    }
}

// MARK: - Pin annotation en el mapa

private struct PinMapAnnotation: View {
    let pin: PinAdvertencia
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Image(systemName: pin.icono)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(pin.colorFondo)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                Triangle()
                    .fill(pin.colorFondo)
                    .frame(width: 8, height: 5)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
