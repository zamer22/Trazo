import CoreLocation
import MapKit
import SwiftUI

struct MarioKartSessionView: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.dismiss) private var dismiss

    let club: Club
    let sesion: SesionClub
    let clubService: ClubService

    @State private var mostrarAISheet = false
    @State private var mostrarManualSheet = false
    @State private var rutaParaCorrer: RoutePlan?
    @State private var iniciando = false
    @State private var locationManager = LocationManager()
    @State private var rutaGanadora: RoutePlan?
    @State private var animandoRuleta = false
    @State private var ruletaIdx = 0
    @State private var mostrarAlertaRuta = false

    private var esModoRuleta: Bool { sesion.modo == "ruleta" }
    private var sesionCorriendo: Bool { clubService.sesionActiva?.estado == "corriendo" }

    var body: some View {
        ZStack {
            TrazoColors.background.ignoresSafeArea()
            contenidoPrincipal
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            clubService.iniciarPollingSesion(clubId: club.id)
        }
        .onDisappear { clubService.detenerPolling() }
        .onChange(of: clubService.sesionActiva?.estado) { _, _ in }
        .onChange(of: clubService.sesionActiva) { _, nueva in
            if nueva == nil { dismiss() }
        }
        .sheet(isPresented: $mostrarAISheet) {
            if let loc = locationManager.userLocation {
                AITrazoSheet(userLocation: loc) { plan in
                    Task { await proponerRuta(plan) }
                }
                .presentationDetents([.large])
                .presentationCornerRadius(TrazoRadius.lg)
                .presentationBackground(TrazoColors.background)
            }
        }
        .sheet(isPresented: $mostrarManualSheet) {
            MarioKartManualProposalSheet(
                userLocation: locationManager.userLocation,
                profile: profile,
                onPropose: { plan in
                    Task { await proponerRuta(plan) }
                }
            )
            .presentationDetents([.large])
            .presentationCornerRadius(TrazoRadius.lg)
            .presentationBackground(TrazoColors.background)
        }
        .fullScreenCover(item: $rutaParaCorrer) { plan in
            RunningActiveView(plan: plan)
                .onAppear { ActiveRunManager.shared.hayCorridaActiva = true }
                .onDisappear { ActiveRunManager.shared.hayCorridaActiva = false }
        }
        .alert("Ya hay una corrida activa", isPresented: $mostrarAlertaRuta) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text("Finaliza tu corrida actual antes de unirte a esta sesión.")
        }
    }

    // MARK: - Contenido principal

    private var contenidoPrincipal: some View {
        VStack(spacing: 0) {
            encabezado
            Divider().opacity(0.15)
            ScrollView {
                VStack(spacing: TrazoSpacing.xl) {
                    modoHeader
                    if sesionCorriendo {
                        corridaActivaView
                    } else {
                        rutasSection
                        accionesSection
                    }
                }
                .padding(TrazoSpacing.xl)
            }
        }
    }

    // MARK: - Encabezado

    private var encabezado: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(TrazoColors.textSecondary)
            }
            Spacer()
            Text(club.nombre).font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
            Spacer()
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
    }

    // MARK: - Modo header

    private var modoHeader: some View {
        VStack(spacing: TrazoSpacing.md) {
            Image(systemName: esModoRuleta ? "dice.fill" : "checklist")
                .font(.system(size: 44))
                .foregroundStyle(TrazoColors.routeTeal)
            Text(esModoRuleta ? "Modo Ruleta" : "Modo Votación")
                .font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
            Text(esModoRuleta
                 ? "Todos proponen rutas y la ruleta decide."
                 : "Propón rutas y voten por la favorita.")
                .font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Rutas propuestas

    private var rutasSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Text("Rutas propuestas (\(clubService.rutasPropuestas.count))")
                    .font(TrazoTypography.headline()).foregroundStyle(TrazoColors.textPrimary)
                Spacer()
                if clubService.rutasPropuestas.isEmpty {
                    ProgressView().scaleEffect(0.8).tint(TrazoColors.routeTeal)
                }
            }
            if clubService.rutasPropuestas.isEmpty {
                Text("Nadie ha propuesto una ruta todavía. Sé el primero.")
                    .font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary)
                    .padding(TrazoSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .background(TrazoColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            } else {
                ForEach(clubService.rutasPropuestas) { ruta in
                    rutaCard(ruta)
                }
            }
        }
    }

    private func rutaCard(_ ruta: RutaPropuesta) -> some View {
        let plan = parsearPlan(ruta.routePlanJson)
        let esElMio = ruta.userId == profile?.id
        let voté = clubService.miVotoId == ruta.id

        return VStack(alignment: .leading, spacing: 0) {
            if let p = plan, p.coordinates.count > 1 {
                miniMapaRuta(p)
            }
            VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Propuesta por \(ruta.nombreUsuario)")
                            .font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary)
                        HStack(spacing: TrazoSpacing.md) {
                            if let p = plan {
                                Label(String(format: "%.1f km", p.distanceKm), systemImage: "figure.run")
                                Label("\(p.estimatedMinutes) min", systemImage: "clock")
                                Label("\(p.desnivel)", systemImage: "arrow.up.right")
                            }
                        }
                        .font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textPrimary)
                    }
                    Spacer()
                    if !esModoRuleta && !esElMio {
                        Button {
                            Task { try? await clubService.votar(sesionId: sesion.id, rutaId: ruta.id, userId: profile!.id) }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: voté ? "hand.thumbsup.fill" : "hand.thumbsup")
                                Text("\(ruta.votos)")
                            }
                            .font(TrazoTypography.caption())
                            .foregroundStyle(voté ? .white : TrazoColors.routeTeal)
                            .padding(.horizontal, TrazoSpacing.md).padding(.vertical, TrazoSpacing.sm)
                            .background(voté ? TrazoColors.routeTeal : TrazoColors.routeTeal.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(TrazoSpacing.lg)
        }
        .background(TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous)
                .strokeBorder(voté ? TrazoColors.routeTeal.opacity(0.6) : Color.clear, lineWidth: 1.5)
        )
    }

    private func miniMapaRuta(_ plan: RoutePlan) -> some View {
        let coords = plan.coordinates
        let region = MKCoordinateRegion(
            center: coords[coords.count / 2],
            span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
        )
        let camPos = MapCameraPosition.region(region)
        return Map(position: .constant(camPos)) {
            MapPolyline(coordinates: coords).stroke(TrazoColors.routeTeal, lineWidth: 3)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .mapControls { }
        .frame(height: 100)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: TrazoRadius.md, topTrailingRadius: TrazoRadius.md))
        .allowsHitTesting(false)
    }

    // MARK: - Acciones

    private var accionesSection: some View {
        VStack(spacing: TrazoSpacing.md) {
            HStack(spacing: TrazoSpacing.sm) {
                Button {
                    mostrarAISheet = true
                } label: {
                    proposeButtonLabel(icono: "sparkles", titulo: "Con IA", color: TrazoColors.accentOrange)
                }
                Button {
                    mostrarManualSheet = true
                } label: {
                    proposeButtonLabel(icono: "map", titulo: "Manual", color: TrazoColors.routeTeal)
                }
            }

            if clubService.rutasPropuestas.count >= 1 {
                TrazoButton(
                    title: iniciando ? "Iniciando..." : (esModoRuleta ? "Girar ruleta" : "Correr la más votada"),
                    style: .primary,
                    isEnabled: !iniciando
                ) {
                    Task { await iniciarCorrida() }
                }
            }
        }
    }

    private func proposeButtonLabel(icono: String, titulo: String, color: Color) -> some View {
        HStack(spacing: TrazoSpacing.xs) {
            Image(systemName: icono)
            Text("Proponer \(titulo)")
        }
        .font(TrazoTypography.body().weight(.semibold))
        .foregroundStyle(color)
        .frame(maxWidth: .infinity)
        .padding(.vertical, TrazoSpacing.md)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
    }

    // MARK: - Corrida activa

    private var corridaActivaView: some View {
        VStack(spacing: TrazoSpacing.xl) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 56))
                .foregroundStyle(TrazoColors.routeTeal)
            Text("La ruta fue elegida").font(TrazoTypography.title()).foregroundStyle(TrazoColors.textPrimary)
            Text("Todos los miembros ya pueden correr la ruta seleccionada.")
                .font(TrazoTypography.body()).foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)
            if let json = clubService.sesionActiva?.rutaGanadoraJson, let plan = parsearPlan(json) {
                TrazoButton(title: "Empezar a correr") {
                    rutaParaCorrer = plan
                }
            }
            TrazoButton(title: "Finalizar sesión", style: .secondary) {
                Task {
                    if let sesionId = clubService.sesionActiva?.id {
                        try? await clubService.finalizarSesion(sesionId: sesionId)
                    }
                    dismiss()
                }
            }
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Lógica

    private func proponerRuta(_ plan: RoutePlan) async {
        guard let uid = profile?.id else { return }
        guard let json = codificarPlan(plan) else { return }
        try? await clubService.proponerRuta(
            sesionId: sesion.id, userId: uid,
            nombreUsuario: profile?.displayName ?? "Runner",
            routePlanJson: json
        )
    }

    private func iniciarCorrida() async {
        if ActiveRunManager.shared.hayCorridaActiva { mostrarAlertaRuta = true; return }
        iniciando = true
        defer { iniciando = false }
        if let json = try? await clubService.iniciarCorrida(sesionId: sesion.id),
           let plan = parsearPlan(json) {
            rutaParaCorrer = plan
        }
    }

    private func decodificarYCorrer(_ json: String) {
        if let plan = parsearPlan(json) { rutaParaCorrer = plan }
    }

    private func codificarPlan(_ plan: RoutePlan) -> String? {
        let coords = plan.coordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }
        let dict: [String: Any] = [
            "distanceKm": plan.distanceKm,
            "estimatedMinutes": plan.estimatedMinutes,
            "estimatedCalories": plan.estimatedCalories,
            "gananciaElevacionM": plan.gananciaElevacionM,
            "averagePace": plan.averagePace,
            "coordinates": coords
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func parsearPlan(_ json: String) -> RoutePlan? {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let distanceKm = dict["distanceKm"] as? Double,
              let estimatedMinutes = dict["estimatedMinutes"] as? Int,
              let estimatedCalories = dict["estimatedCalories"] as? Int,
              let ganancia = dict["gananciaElevacionM"] as? Int,
              let coordsRaw = dict["coordinates"] as? [[String: Double]] else { return nil }
        let coords = coordsRaw.compactMap { c -> CLLocationCoordinate2D? in
            guard let lat = c["lat"], let lon = c["lon"] else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        let dest = coords.last ?? CLLocationCoordinate2D(latitude: 25.686, longitude: -100.316)
        return RoutePlan(
            destinationName: "Club \(club.nombre)",
            destination: dest,
            routePoints: coords,
            distanceKm: distanceKm,
            estimatedMinutes: estimatedMinutes,
            estimatedCalories: estimatedCalories,
            averagePace: dict["averagePace"] as? String ?? "6:30 /km",
            gananciaElevacionM: ganancia
        )
    }
}
