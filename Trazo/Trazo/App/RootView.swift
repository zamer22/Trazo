import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var auth = AuthService()
    @State private var sincronizando = false
    @Query private var profiles: [UserProfile]

    private var activeProfile: UserProfile? {
        guard let uid = auth.userId else { return nil }
        return profiles.first { $0.id == uid }
    }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                AuthView()
            } else if auth.registroReciente {
                OnboardingView()
            } else if sincronizando {
                pantallaEspera
            } else {
                MainTabView()
                    .environment(\.currentUserProfile, activeProfile)
            }
        }
        .environment(auth)
        .background(TrazoColors.background)
        .task(id: auth.userId) {
            await syncProfile()
        }
    }

    private var pantallaEspera: some View {
        VStack(spacing: TrazoSpacing.md) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(TrazoColors.routeTeal)
            ProgressView()
                .tint(TrazoColors.routeTeal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func syncProfile() async {
        guard let uid = auth.userId, let correo = auth.email else { return }
        guard !auth.registroReciente else { return } // registro nuevo: completeOnboarding crea el perfil
        guard activeProfile == nil else { return }   // login existente: perfil ya en SwiftData

        sincronizando = true
        defer { sincronizando = false }

        let remoto = try? await UserProfileRepository.fetch(userId: uid)
        let perfil = UserProfile(id: uid, email: correo, remoto: remoto)
        modelContext.insert(perfil)
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

#Preview {
    RootView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
