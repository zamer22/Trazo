import MapKit
import SwiftUI

struct RunningMapExplorerView: View {
    @Environment(\.currentUserProfile) private var profile

    @State private var locationManager = LocationManager()
    @State private var searchService = AddressSearchService()
    @State private var aiOptimizer = AIRouteOptimizer()
    @State private var destination: MapDestination?
    @State private var isCalculatingRoute = false
    @State private var errorMessage: String?
    @State private var recenterTrigger = 0
    @State private var popularLocations: [PopularLocation] = PopularLocationsService.defaults
    @State private var isSearchSheetPresented = false
    @State private var isAISheetPresented = false
    @State private var esIdaVuelta = false
    @State private var aiRecomendacion: RecomendacionRuta?
    @State private var planOptimizado: RoutePlan?
    @State private var mostrarRecomendacionSheet = false

    private let locationButtonGap: CGFloat = TrazoSpacing.md

    let onRouteReady: (RoutePlan) -> Void

    private var locationButtonBottomInset: CGFloat {
        RunningSearchMetrics.collapsedBarHeight + locationButtonGap + (destination != nil ? destinationPanelHeight : 0)
    }

    private var destinationPanelHeight: CGFloat { 168 }

    var body: some View {
        ZStack(alignment: .bottom) {
            RunningRouteMapView(
                userLocation: locationManager.userLocation,
                destination: destination,
                routeCoordinates: [],
                allowsPlacingPin: true,
                recenterTrigger: recenterTrigger,
                onMapLongPress: { coordinate in
                    destination = MapDestination(name: "Punto en el mapa", coordinate: coordinate)
                }
            )
            .ignoresSafeArea()

            VStack {
                Spacer()
                HStack {
                    aiButton
                        .padding(.leading, TrazoSpacing.lg)
                    Spacer()
                    recenterButton
                        .padding(.trailing, TrazoSpacing.lg)
                }
                .padding(.bottom, locationButtonBottomInset)
            }

            VStack(spacing: 0) {
                if destination != nil {
                    destinationPanel
                }
                RunningCollapsedSearchBar {
                    isSearchSheetPresented = true
                }
            }
            .background(.ultraThinMaterial)
            .background(TrazoColors.elevated.opacity(0.9))
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .sheet(isPresented: $isAISheetPresented) {
            AITrazoSheet(
                userLocation: locationManager.userLocation,
                onRouteReady: onRouteReady
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(TrazoRadius.lg)
            .presentationBackground(TrazoColors.background)
        }
        .sheet(isPresented: $isSearchSheetPresented) {
            RunningLocationSearchSheet(
                searchService: searchService,
                popularLocations: popularLocations,
                onSelect: { selected in
                    destination = selected
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(TrazoRadius.lg)
            .presentationBackground(TrazoColors.background)
        }
        .sheet(isPresented: $mostrarRecomendacionSheet) {
            if let rec = aiRecomendacion, var plan = planOptimizado {
                AIRecomendacionSheet(
                    recomendacion: rec,
                    onVerTrazo: {
                        mostrarRecomendacionSheet = false
                        plan.aiRazon = rec.razon
                        onRouteReady(plan)
                    },
                    onClose: { mostrarRecomendacionSheet = false }
                )
                .presentationDetents([.medium])
                .presentationCornerRadius(TrazoRadius.lg)
                .presentationBackground(TrazoColors.background)
            }
        }
        .alert("No se pudo crear el Trazo", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
            updateSearchRegion()
            Task { await loadPopularLocations() }
        }
        .onChange(of: locationManager.userLocation?.latitude) { _, _ in
            updateSearchRegion()
            Task { await loadPopularLocations() }
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
    }

    private var destinationPanel: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(TrazoColors.accentOrange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Destino")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                    Text(destination?.name.isEmpty == false ? destination!.name : "Punto en el mapa")
                        .font(TrazoTypography.body())
                        .foregroundStyle(TrazoColors.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    destination = nil
                    esIdaVuelta = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }

            HStack(spacing: TrazoSpacing.sm) {
                modoChip(titulo: "Solo ida", icono: "arrow.right", activo: !esIdaVuelta) {
                    esIdaVuelta = false
                }
                modoChip(titulo: "Ida y vuelta", icono: "arrow.left.arrow.right", activo: esIdaVuelta) {
                    esIdaVuelta = true
                }
                Spacer(minLength: 0)
            }

            Button {
                Task { await optimizarConIA() }
            } label: {
                HStack(spacing: TrazoSpacing.xs) {
                    if isCalculatingRoute {
                        ProgressView().scaleEffect(0.8).tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(isCalculatingRoute ? "Analizando ruta..." : "Crear Trazo")
                }
                .font(TrazoTypography.body().weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TrazoSpacing.md)
                .background(TrazoColors.routeTeal)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
            }
            .disabled(isCalculatingRoute)
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.top, TrazoSpacing.md)
        .padding(.bottom, TrazoSpacing.sm)
    }

    private func modoChip(titulo: String, icono: String, activo: Bool, accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Label(titulo, systemImage: icono)
                .font(TrazoTypography.caption().weight(.semibold))
                .foregroundStyle(activo ? .white : TrazoColors.textSecondary)
                .padding(.horizontal, TrazoSpacing.md)
                .padding(.vertical, TrazoSpacing.sm)
                .background(activo ? TrazoColors.routeTeal : Color.clear)
                .overlay(
                    Capsule().strokeBorder(activo ? Color.clear : TrazoColors.textSecondary.opacity(0.3), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    private var aiButton: some View {
        Button {
            isAISheetPresented = true
        } label: {
            HStack(spacing: TrazoSpacing.xs) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                Text("Trazo IA")
                    .font(TrazoTypography.caption())
            }
            .foregroundStyle(TrazoColors.accentOrange)
            .padding(.horizontal, TrazoSpacing.md)
            .padding(.vertical, TrazoSpacing.sm)
            .background(.ultraThinMaterial)
            .background(TrazoColors.elevated.opacity(0.9))
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .accessibilityLabel("Generar ruta con inteligencia artificial")
    }

    private var recenterButton: some View {
        Button {
            locationManager.startUpdating()
            recenterTrigger += 1
        } label: {
            Image(systemName: "location.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(TrazoColors.routeTeal)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .background(TrazoColors.elevated.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .accessibilityLabel("Ir a mi ubicación")
    }

    private func updateSearchRegion() {
        guard let coordinate = locationManager.userLocation else { return }
        searchService.setRegion(center: coordinate)
    }

    private func loadPopularLocations() async {
        guard let coordinate = locationManager.userLocation else { return }
        popularLocations = await PopularLocationsService.nearby(from: coordinate)
    }

    private func crearTrazoManual() async {
        guard let destination else { return }
        guard let userLocation = locationManager.userLocation else {
            errorMessage = RouteCalculatorError.missingUserLocation.errorDescription
            return
        }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        do {
            let plan: RoutePlan
            if esIdaVuelta {
                plan = try await RouteCalculator.calculateRoundTrip(
                    to: destination, from: userLocation, profile: profile)
            } else {
                plan = try await RouteCalculator.calculate(
                    to: destination, from: userLocation, profile: profile)
            }
            onRouteReady(plan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func optimizarConIA() async {
        guard let destination else { return }
        guard let userLocation = locationManager.userLocation else {
            errorMessage = RouteCalculatorError.missingUserLocation.errorDescription
            return
        }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        await aiOptimizer.optimizar(destino: destination, origen: userLocation, perfil: profile)

        switch aiOptimizer.estado {
        case .listo(let plan, let recomendacion):
            esIdaVuelta = recomendacion.modoRecomendado.lowercased().contains("vuelta")
            planOptimizado = plan
            aiRecomendacion = recomendacion
            mostrarRecomendacionSheet = true
        case .error(let msg):
            errorMessage = msg
        default:
            break
        }
    }
}

// MARK: - Hoja de recomendación IA

struct AIRecomendacionSheet: View {
    let recomendacion: RecomendacionRuta
    let onVerTrazo: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: TrazoSpacing.lg) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(TrazoColors.accentOrange)
                Text("Trazo IA recomienda")
                    .font(TrazoTypography.title())
                    .foregroundStyle(TrazoColors.textPrimary)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                Text(recomendacion.etiqueta)
                    .font(TrazoTypography.headline())
                    .foregroundStyle(.white)
                    .padding(.horizontal, TrazoSpacing.md)
                    .padding(.vertical, TrazoSpacing.sm)
                    .background(TrazoColors.routeTeal)
                    .clipShape(Capsule())

                HStack(spacing: TrazoSpacing.sm) {
                    Image(systemName: recomendacion.modoRecomendado.lowercased().contains("vuelta") ? "arrow.left.arrow.right" : "arrow.right")
                        .foregroundStyle(TrazoColors.routeTeal)
                    Text(recomendacion.modoRecomendado.lowercased().contains("vuelta") ? "Modo: Ida y vuelta" : "Modo: Solo ida")
                        .font(TrazoTypography.body().weight(.semibold))
                        .foregroundStyle(TrazoColors.textPrimary)
                }

                Text(recomendacion.razon)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))

            TrazoButton(title: "Ver Trazo") {
                onVerTrazo()
            }

            Spacer(minLength: 0)
        }
        .padding(TrazoSpacing.xl)
        .background(TrazoColors.background)
    }
}
