import SwiftData
import SwiftUI

struct RootView: View {
    @Query private var profiles: [UserProfile]

    private var activeProfile: UserProfile? {
        profiles.first { $0.hasCompletedOnboarding }
    }

    var body: some View {
        Group {
            if let profile = activeProfile {
                MainTabView()
                    .environment(\.currentUserProfile, profile)
            } else {
                OnboardingView()
            }
        }
        .background(TrazoColors.background)
    }
}

private struct CurrentUserProfileKey: EnvironmentKey {
    static let defaultValue: UserProfile? = nil
}

extension EnvironmentValues {
    var currentUserProfile: UserProfile? {
        get { self[CurrentUserProfileKey.self] }
        set { self[CurrentUserProfileKey.self] = newValue }
    }
}

#Preview("Onboarding") {
    RootView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
