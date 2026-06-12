import SwiftUI

struct RestaurantsHomeView: View {
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .map

    enum ViewMode: String, CaseIterable {
        case map = "Mapa"
        case list = "Lista"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: TrazoSpacing.lg) {
                TrazoSearchBar(text: $searchText, placeholder: "Buscar restaurantes")

                Picker("Vista", selection: $viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch viewMode {
                    case .map:
                        mapPlaceholder
                    case .list:
                        restaurantList
                    }
                }
            }
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.background)
            .navigationTitle("Locales")
        }
    }

    private var mapPlaceholder: some View {
        RoundedRectangle(cornerRadius: TrazoRadius.lg, style: .continuous)
            .fill(TrazoColors.surface)
            .overlay {
                VStack(spacing: TrazoSpacing.md) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 40))
                        .foregroundStyle(TrazoColors.accentOrange)
                    Text("Mapa de restaurantes")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)
                    Text("Próximamente con locales cerca de tus rutas")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
    }

    private var restaurantList: some View {
        ScrollView {
            LazyVStack(spacing: TrazoSpacing.md) {
                ForEach(MockRestaurant.samples) { restaurant in
                    restaurantRow(restaurant)
                }
            }
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
