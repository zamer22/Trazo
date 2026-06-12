import CoreLocation
import MapKit
import SwiftUI

struct RunningActiveView: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss

    @State private var locationManager = LocationManager()
    @State private var sessionTracker: RunningSessionTracker
    @State private var pines: [PinAdvertencia] = []
    @State private var isReportando = false
    @State private var mostrarAlertaPin: PinAdvertencia?
    @State private var statsFinales: RunStats?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var barraStatsHeight: CGFloat = 160

    let plan: RoutePlan

    init(plan: RoutePlan) {
        self.plan = plan
        self._sessionTracker = State(initialValue: RunningSessionTracker(plan: plan))
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
        .alert(isPresented: .init(
            get: { mostrarAlertaPin != nil },
            set: { if !$0 { mostrarAlertaPin = nil } }
        )) {
            let pin = mostrarAlertaPin!
            return Alert(
                title: Text("⚠️ \(pin.etiqueta) adelante"),
                message: Text("Hay un reporte de \(pin.etiqueta.lowercased()) cerca de tu ruta. Considera cambiar de camino."),
                primaryButton: .default(Text("Ya no está")) {
                    Task { try? await PinAdvertenciaService.votarResuelto(pinId: pin.id) }
                },
                secondaryButton: .cancel(Text("Entendido"))
            )
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            sessionTracker.iniciar()
            Task { await cargarPines() }
        }
        .onDisappear {
            sessionTracker.pausar()
            locationManager.stopUpdating()
        }
        .onChange(of: locationManager.userLocation?.latitude) { _, _ in
            guard let loc = locationManager.userLocation else { return }
            seguirConCamara(loc)
            sessionTracker.actualizarUbicacion(loc)
            verificarPinesCercanos(loc)
            if sessionTracker.haTerminado && statsFinales == nil {
                finalizarConStats(completado: true)
            }
        }
        .onChange(of: locationManager.lastFullLocation?.timestamp) { _, _ in
            guard let loc = locationManager.lastFullLocation else { return }
            sessionTracker.actualizarVelocidad(loc)
        }
    }

    // MARK: - Mapa

    private var mapaActivo: some View {
        Map(position: $cameraPosition) {
            // Tramo restante (muted)
            if sessionTracker.coordenadasRestantes.count > 1 {
                MapPolyline(coordinates: sessionTracker.coordenadasRestantes)
                    .stroke(TrazoColors.routeTeal.opacity(0.45), lineWidth: 4)
            } else {
                MapPolyline(coordinates: plan.coordinates)
                    .stroke(TrazoColors.routeTeal.opacity(0.45), lineWidth: 4)
            }
            // Tramo cubierto (brillante)
            if sessionTracker.coordenadasCubiertas.count > 1 {
                MapPolyline(coordinates: sessionTracker.coordenadasCubiertas)
                    .stroke(TrazoColors.routeTeal, lineWidth: 5)
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
                        mostrarAlertaPin = pin
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .automatic, pointsOfInterest: .excludingAll))
        .mapControls { }
    }

    // MARK: - Barra superior

    private var barraTop: some View {
        HStack {
            Button {
                sessionTracker.pausar()
                finalizarConStats(completado: false)
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
        .accessibilityLabel("Reportar problema en la ruta")
    }

    // MARK: - Panel de stats

    private var panelStats: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, TrazoSpacing.md)

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
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(Color.black.opacity(0.55))
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: TrazoRadius.lg, topTrailingRadius: TrazoRadius.lg))
        .ignoresSafeArea(edges: .bottom)
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
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .camera(MapCamera(
                centerCoordinate: loc,
                distance: 350,
                heading: 0,
                pitch: 0
            ))
        }
    }

    private func cargarPines() async {
        guard let loc = locationManager.userLocation else { return }
        pines = (try? await PinAdvertenciaService.fetchActivos(cerca: loc, radioKm: 3.0)) ?? []
    }

    private func agregarPinLocal(tipo: String, coord: CLLocationCoordinate2D) async {
        // Recarga desde Supabase para tener el id real
        await cargarPines()
    }

    private func finalizarConStats(completado: Bool) {
        statsFinales = RunStats(
            distanciaRecorridaKm: sessionTracker.distanciaRecorridaKm,
            elapsedSeconds: sessionTracker.elapsedSeconds,
            ritmoStr: sessionTracker.ritmoActualStr,
            calorias: sessionTracker.caloriasQuemadas,
            completado: completado,
            planDistanciaKm: plan.distanceKm,
            planGananciaElevacionM: plan.gananciaElevacionM
        )
    }

    private func verificarPinesCercanos(_ loc: CLLocationCoordinate2D) {
        guard mostrarAlertaPin == nil else { return }
        let locUsuario = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
        let pinCercano = pines.first { pin in
            let locPin = CLLocation(latitude: pin.latitud, longitude: pin.longitud)
            return locUsuario.distance(from: locPin) < 80 // dentro de 80m
        }
        if let pin = pinCercano {
            mostrarAlertaPin = pin
        }
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
