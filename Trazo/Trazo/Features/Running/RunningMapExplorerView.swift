import MapKit
import SwiftUI

struct RunningMapExplorerView: View {
    @Environment(\.currentUserProfile) private var profile

    @State private var locationManager = LocationManager()
    @State private var searchService = AddressSearchService()
    @State private var destination: MapDestination?
    @State private var isCalculatingRoute = false
    @State private var errorMessage: String?
    @State private var recenterTrigger = 0
    @State private var destinationFitTrigger = 0
    @State private var popularLocations: [PopularLocation] = PopularLocationsService.defaults
    @State private var searchHistory = SearchHistoryStore()
    @State private var isSearchSheetPresented = false

    private let locationButtonGap: CGFloat = TrazoSpacing.md
    private let actionButtonHeight: CGFloat = 44

    let onRouteReady: (RoutePlan) -> Void

    private var locationButtonBottomInset: CGFloat {
        RunningSearchMetrics.collapsedBarHeight + locationButtonGap
    }

    private var mapBottomEdgePadding: CGFloat {
        locationButtonBottomInset + actionButtonHeight + TrazoSpacing.md
    }

    var body: some View {
        GeometryReader { geometry in
            let mapEdgePadding = UIEdgeInsets(
                top: geometry.safeAreaInsets.top + 56,
                left: 24,
                bottom: mapBottomEdgePadding + geometry.safeAreaInsets.bottom,
                right: 24
            )

            ZStack(alignment: .bottom) {
                RunningRouteMapView(
                    userLocation: locationManager.userLocation,
                    destination: destination,
                    routeCoordinates: [],
                    allowsPlacingPin: true,
                    recenterTrigger: recenterTrigger,
                    destinationFitTrigger: destinationFitTrigger,
                    mapSize: geometry.size,
                    mapEdgePadding: mapEdgePadding,
                    onMapLongPress: { coordinate in
                        setDestination(MapDestination(name: "", coordinate: coordinate))
                    }
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()
                    ZStack {
                        if destination != nil {
                            generateTrazoButton
                        }

                        HStack {
                            Spacer()
                            recenterButton
                        }
                    }
                    .padding(.horizontal, TrazoSpacing.lg)
                    .padding(.bottom, locationButtonBottomInset)
                }

                RunningCollapsedSearchBar {
                    isSearchSheetPresented = true
                }
            }
        }
        .toolbarBackground(.hidden, for: .tabBar)
        .sheet(isPresented: $isSearchSheetPresented) {
            RunningLocationSearchSheet(
                searchService: searchService,
                searchHistory: searchHistory,
                popularLocations: popularLocations,
                onSelect: { selected in
                    setDestination(selected)
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(TrazoRadius.lg)
            .presentationBackground(TrazoColors.surface)
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

    private var generateTrazoButton: some View {
        Button {
            Task { await confirmDestination() }
        } label: {
            HStack(spacing: TrazoSpacing.sm) {
                if isCalculatingRoute {
                    ProgressView()
                        .tint(.white)
                }

                Text("Generar Trazo")
                    .font(TrazoTypography.headline())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, TrazoSpacing.lg)
            .frame(height: actionButtonHeight)
            .background(TrazoColors.routeTeal)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .disabled(isCalculatingRoute)
        .accessibilityLabel("Generar Trazo")
    }

    private var recenterButton: some View {
        Button {
            destination = nil
            locationManager.startUpdating()
            recenterTrigger += 1
        } label: {
            Image(systemName: "location.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(TrazoColors.routeTeal)
                .frame(width: actionButtonHeight, height: actionButtonHeight)
                .background(.ultraThinMaterial)
                .background(TrazoColors.elevated.opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
        }
        .accessibilityLabel("Ir a mi ubicación")
    }

    private func setDestination(_ newDestination: MapDestination) {
        destination = newDestination
        destinationFitTrigger += 1
    }

    private func updateSearchRegion() {
        guard let coordinate = locationManager.userLocation else { return }
        searchService.setRegion(center: coordinate)
    }

    private func loadPopularLocations() async {
        guard let coordinate = locationManager.userLocation else { return }
        popularLocations = await PopularLocationsService.nearby(from: coordinate)
    }

    private func confirmDestination() async {
        guard let destination else { return }
        guard let userLocation = locationManager.userLocation else {
            errorMessage = RouteCalculatorError.missingUserLocation.errorDescription
            return
        }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        do {
            let plan = try await RouteCalculator.calculate(
                to: destination,
                from: userLocation,
                profile: profile
            )
            onRouteReady(plan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
