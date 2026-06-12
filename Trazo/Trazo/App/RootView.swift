import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService()
    @Query private var profiles: [UserProfile]

    private var activeProfile: UserProfile? {
        guard let uid = auth.userId else { return nil }
        return profiles.first { $0.id == uid }
    }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                AuthView()
            } else if let profile = activeProfile, profile.hasCompletedOnboarding {
                MainTabView()
                    .environment(\.currentUserProfile, profile)
            } else {
                OnboardingView()
            }
        }
        .environment(auth)
        .background(TrazoColors.background)
        .task(id: auth.userId) {
            await syncProfile()
        }
    }

    private func syncProfile() async {
        guard let uid = auth.userId, let correo = auth.email else { return }
        if profiles.first(where: { $0.id == uid }) != nil { return }

        let remoto = try? await UserProfileRepository.fetch(userId: uid)
        let profile = UserProfile(id: uid, email: correo, remoto: remoto)
        modelContext.insert(profile)
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
