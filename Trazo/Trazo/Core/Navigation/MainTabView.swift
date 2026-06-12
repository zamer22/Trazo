import SwiftData
import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: MainTab = .running

    var body: some View {
        TabView(selection: $selectedTab) {
            RunningHomeView()
                .tabItem {
                    Label("Correr", systemImage: "figure.run")
                }
                .tag(MainTab.running)

            RestaurantsHomeView()
                .tabItem {
                    Label("Locales", systemImage: "fork.knife")
                }
                .tag(MainTab.restaurants)

            CommunityHomeView()
                .tabItem {
                    Label("Comunidad", systemImage: "person.3")
                }
                .tag(MainTab.community)

            ProfileView()
                .tabItem {
                    Label("Perfil", systemImage: "person.circle")
                }
                .tag(MainTab.profile)
        }
        .tint(TrazoColors.tabActive)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
