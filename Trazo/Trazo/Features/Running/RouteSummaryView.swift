import CoreLocation
import SwiftUI

struct RouteSummaryView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: RoutePlan

    @State private var statsPanelHeight: CGFloat = 320

    var body: some View {
        GeometryReader { geometry in
            let topPadding = geometry.safeAreaInsets.top + 56
            let bottomPadding = statsPanelHeight

            ZStack(alignment: .bottom) {
                RunningRouteMapView(
                    destination: MapDestination(
                        name: plan.destinationName,
                        coordinate: plan.destinationCoordinate
                    ),
                    routeCoordinates: plan.coordinates,
                    allowsPlacingPin: false,
                    mapSize: geometry.size,
                    mapEdgePadding: UIEdgeInsets(
                        top: topPadding,
                        left: 24,
                        bottom: bottomPadding,
                        right: 24
                    )
                )
                .ignoresSafeArea()

                statsPanel
                    .offset(y: 34)
                    .background {
                        GeometryReader { panelGeo in
                            Color.clear
                                .onAppear { statsPanelHeight = panelGeo.size.height }
                                .onChange(of: panelGeo.size.height) { _, height in
                                    statsPanelHeight = height
                                }
                        }
                    }
            }
        }
        .navigationTitle("Ruta de hoy")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    circularToolbarIcon("chevron.left")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: shareText) {
                    circularToolbarIcon("square.and.arrow.up")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var statsPanel: some View {
        VStack(spacing: TrazoSpacing.md) {
            Capsule()
                .fill(TrazoColors.textSecondary.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, TrazoSpacing.sm)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: TrazoSpacing.md
            ) {
                TrazoMapStatCard(label: "Distancia", value: formattedDistance)
                TrazoMapStatCard(label: "Tiempo est.", value: "\(plan.estimatedMinutes) min")
                TrazoMapStatCard(label: "Ritmo prom.", value: plan.averagePace)
                TrazoMapStatCard(label: "Cadencia", value: "90 BPM")
                TrazoMapStatCard(label: "Calorías est.", value: "~\(plan.estimatedCalories) Cal")

                TrazoButton(title: "Empezar a correr") {}
            }
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.bottom, TrazoSpacing.lg)
        }
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                Rectangle()
                    .fill(TrazoColors.surface.opacity(0.55))
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: TrazoRadius.lg,
                topTrailingRadius: TrazoRadius.lg
            )
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private var formattedDistance: String {
        String(format: "%.1f KM", plan.distanceKm)
    }

    private var shareText: String {
        "Mi ruta en Trazo: \(formattedDistance) hacia \(plan.destinationName)"
    }

    private func circularToolbarIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(TrazoColors.textPrimary)
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial)
            .background(TrazoColors.surface.opacity(0.7))
            .clipShape(Circle())
    }
}

#Preview {
    NavigationStack {
        RouteSummaryView(
            plan: RoutePlan(
                destinationName: "Parque Central",
                destination: CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
                routePoints: [
                    CLLocationCoordinate2D(latitude: 19.4300, longitude: -99.1350),
                    CLLocationCoordinate2D(latitude: 19.4326, longitude: -99.1332),
                ],
                distanceKm: 12.5,
                estimatedMinutes: 90,
                estimatedCalories: 1200,
                averagePace: "6:30 /km"
            )
        )
    }
}
