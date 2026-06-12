import MapKit
import SwiftUI

struct RestaurantsHomeView: View {
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .map
    @State private var cameraPosition: MapCameraPosition = .automatic

    enum ViewMode: String, CaseIterable {
        case map = "Mapa"
        case list = "Lista"
    }

    private var filteredRestaurants: [MockRestaurant] {
        guard !searchText.isEmpty else { return MockRestaurant.samples }
        return MockRestaurant.samples.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    header

                    Group {
                        switch viewMode {
                        case .map:
                            restaurantMap
                        case .list:
                            restaurantList
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                TrazoBottomSearchBar(text: $searchText, placeholder: "Buscar restaurantes")
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
            .toolbarBackground(.hidden, for: .tabBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Locales")
                .font(TrazoTypography.largeTitle())
                .foregroundStyle(TrazoColors.textPrimary)

            Picker("Vista", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.top, TrazoSpacing.sm)
        .padding(.bottom, TrazoSpacing.md)
        .background(TrazoColors.surface)
    }

    private var restaurantMap: some View {
        Map(position: $cameraPosition, interactionModes: .all) {
            UserAnnotation()
        }
        .mapStyle(.standard(pointsOfInterest: .including([.restaurant, .cafe, .bakery])))
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.lg, style: .continuous))
        .overlay {
            VStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 32))
                    .foregroundStyle(TrazoColors.accentOrange)
                Text("Próximamente con locales cerca de tus Trazos")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, TrazoSpacing.xl)
            }
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            .padding(.horizontal, TrazoSpacing.xl)
        }
    }

    private var restaurantList: some View {
        ScrollView {
            LazyVStack(spacing: TrazoSpacing.md) {
                ForEach(filteredRestaurants) { restaurant in
                    restaurantRow(restaurant)
                }
            }
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.bottom, TrazoBottomChromeMetrics.searchZoneHeight + TrazoSpacing.md)
        }
    }

    private func restaurantRow(_ restaurant: MockRestaurant) -> some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.md) {
                RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous)
                    .fill(TrazoColors.mutedTeal.opacity(0.3))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: restaurant.categoryIcon)
                            .foregroundStyle(TrazoColors.routeTeal)
                    }

                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text(restaurant.name)
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)

                    HStack(spacing: TrazoSpacing.sm) {
                        Label(String(format: "%.1f", restaurant.rating), systemImage: "star.fill")
                            .foregroundStyle(TrazoColors.accentOrange)
                        Text("· \(restaurant.distance)")
                            .foregroundStyle(TrazoColors.textSecondary)
                    }
                    .font(TrazoTypography.caption())
                }

                Spacer()
            }
        }
    }
}

private struct MockRestaurant: Identifiable {
    let id = UUID()
    let name: String
    let rating: Double
    let distance: String
    let categoryIcon: String

    static let samples: [MockRestaurant] = [
        MockRestaurant(name: "Café Central", rating: 4.5, distance: "0.8 km", categoryIcon: "cup.and.saucer.fill"),
        MockRestaurant(name: "La Terraza", rating: 4.2, distance: "1.2 km", categoryIcon: "fork.knife"),
        MockRestaurant(name: "Green Bowl", rating: 4.8, distance: "1.5 km", categoryIcon: "leaf.fill"),
    ]
}

#Preview {
    RestaurantsHomeView()
}
