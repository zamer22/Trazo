import CoreLocation
import SwiftUI

struct RouteSummaryView: View {
    @Environment(\.dismiss) private var dismiss

    let plan: RoutePlan

    @State private var statsPanelHeight: CGFloat = 320
    @State private var isRunningActive = false
    @State private var mostrarAlertaOtraRuta = false

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
        .navigationTitle("Trazo de hoy")
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

            if let razon = plan.aiRazon {
                HStack(alignment: .top, spacing: TrazoSpacing.sm) {
                    Image(systemName: "sparkles").font(.caption.weight(.semibold)).foregroundStyle(TrazoColors.accentOrange)
                    Text(razon).font(TrazoTypography.caption()).foregroundStyle(TrazoColors.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(TrazoSpacing.md)
                .background(TrazoColors.accentOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                .padding(.horizontal, TrazoSpacing.lg)
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: TrazoSpacing.md
            ) {
                TrazoMapStatCard(label: "Distancia", value: formattedDistance)
                TrazoMapStatCard(label: "Tiempo est.", value: "\(plan.estimatedMinutes) min")
                TrazoMapStatCard(label: "Ritmo prom.", value: plan.averagePace)
                TrazoMapStatCard(label: "Desnivel ↑", value: "\(plan.gananciaElevacionM) m")
                TrazoMapStatCard(label: "Calorías est.", value: "~\(plan.estimatedCalories) Cal")
                TrazoMapStatCard(label: "Terreno", value: plan.desnivel)
            }
            .padding(.horizontal, TrazoSpacing.lg)

            TrazoButton(title: "Empezar a correr") {
                if ActiveRunManager.shared.hayCorridaActiva {
                    mostrarAlertaOtraRuta = true
                } else {
                    isRunningActive = true
                }
            }
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.bottom, TrazoSpacing.lg)
            .fullScreenCover(isPresented: $isRunningActive, onDismiss: { dismiss() }) {
                RunningActiveView(plan: plan)
                    .onAppear { ActiveRunManager.shared.hayCorridaActiva = true }
                    .onDisappear { ActiveRunManager.shared.hayCorridaActiva = false }
            }
            .alert("Ya hay una corrida activa", isPresented: $mostrarAlertaOtraRuta) {
                Button("Entendido", role: .cancel) {}
            } message: {
                Text("Finaliza tu corrida actual antes de iniciar otra.")
            }
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
        "Mi Trazo: \(formattedDistance) hacia \(plan.destinationName)"
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
