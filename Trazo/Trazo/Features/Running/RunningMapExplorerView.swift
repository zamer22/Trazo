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

    let onRouteReady: (RoutePlan) -> Void

    var body: some View {
        ZStack {
            RunningRouteMapView(
                userLocation: locationManager.userLocation,
                destination: destination,
                routeCoordinates: [],
                allowsPlacingPin: true,
                recenterTrigger: recenterTrigger,
                onMapTap: { coordinate in
                    searchService.query = ""
                    destination = MapDestination(name: "Destino seleccionado", coordinate: coordinate)
                },
                onPinDoubleTap: {
                    Task { await confirmDestination() }
                }
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                searchSection
                    .padding(.horizontal, TrazoSpacing.lg)
                    .padding(.top, TrazoSpacing.sm)
                Spacer()
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    recenterButton
                }
                .padding(.trailing, TrazoSpacing.lg)
                .padding(.bottom, TrazoSpacing.lg)
            }

            if isCalculatingRoute {
                ProgressView("Calculando ruta...")
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            }
        }
        .alert("No se pudo crear la ruta", isPresented: .init(
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
        }
        .onDisappear {
            locationManager.stopUpdating()
        }
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

    private var searchSection: some View {
        VStack(spacing: TrazoSpacing.sm) {
            TrazoSearchBar(text: $searchService.query, placeholder: "Buscar dirección")

            if !searchService.results.isEmpty && !searchService.query.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(searchService.results.enumerated()), id: \.offset) { index, result in
                        Button {
                            Task { await selectSearchResult(result) }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.title)
                                    .font(TrazoTypography.body())
                                    .foregroundStyle(TrazoColors.textPrimary)
                                if !result.subtitle.isEmpty {
                                    Text(result.subtitle)
                                        .font(TrazoTypography.caption())
                                        .foregroundStyle(TrazoColors.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(TrazoSpacing.md)
                        }

                        if index < searchService.results.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .background(TrazoColors.elevated.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            }
        }
    }

    private func selectSearchResult(_ result: MKLocalSearchCompletion) async {
        do {
            let resolved = try await searchService.resolve(result)
            searchService.query = ""
            searchService.results = []
            destination = resolved
        } catch {
            errorMessage = error.localizedDescription
        }
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
