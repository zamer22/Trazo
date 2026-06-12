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
    @State private var popularLocations: [PopularLocation] = PopularLocationsService.defaults
    @State private var isSearchSheetPresented = false
    @State private var isAISheetPresented = false

    private let locationButtonGap: CGFloat = TrazoSpacing.md

    let onRouteReady: (RoutePlan) -> Void

    private var locationButtonBottomInset: CGFloat {
        RunningSearchMetrics.collapsedBarHeight + locationButtonGap
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            RunningRouteMapView(
                userLocation: locationManager.userLocation,
                destination: destination,
                routeCoordinates: [],
                allowsPlacingPin: true,
                recenterTrigger: recenterTrigger,
                onMapLongPress: { coordinate in
                    destination = MapDestination(name: "", coordinate: coordinate)
                },
                onPinDoubleTap: {
                    Task { await confirmDestination() }
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

            RunningCollapsedSearchBar {
                isSearchSheetPresented = true
            }
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
