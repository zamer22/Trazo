import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(\.appNavigation) private var navigation

    var body: some View {
        TabView(selection: Binding(
            get: { navigation.selectedTab },
            set: { navigation.selectedTab = $0 }
        )) {
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
        .modelContainer(for: [
            UserProfile.self,
            RunningClub.self,
            ClubMember.self,
            ClubMessage.self,
            ClubInvitation.self,
            RouteProposal.self,
            RouteVote.self,
        ], inMemory: true)
}
