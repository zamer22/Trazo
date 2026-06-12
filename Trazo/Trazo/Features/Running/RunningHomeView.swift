import SwiftUI

struct RunningHomeView: View {
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            RunningMapExplorerView { plan in
                navigationPath.append(plan)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: RoutePlan.self) { plan in
                RouteSummaryView(plan: plan)
            }
        }
    }
}

#Preview {
    RunningHomeView()
        .environment(\.currentUserProfile, UserProfile(displayName: "Diego", hasCompletedOnboarding: true))
}
