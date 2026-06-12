import SwiftData
import SwiftUI

@Observable
final class AppNavigationCoordinator {
    var selectedTab: MainTab = .running
    var pendingJoinInviteCode: String?
    var clubToOpen: RunningClub?

    func openJoinClub(code: String) {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        pendingJoinInviteCode = normalized
        selectedTab = .community
    }

    func clearPendingJoin() {
        pendingJoinInviteCode = nil
    }

    func openClub(_ club: RunningClub) {
        clubToOpen = club
        selectedTab = .community
        clearPendingJoin()
    }
}

private struct AppNavigationCoordinatorKey: EnvironmentKey {
    static let defaultValue = AppNavigationCoordinator()
}

extension EnvironmentValues {
    var appNavigation: AppNavigationCoordinator {
        get { self[AppNavigationCoordinatorKey.self] }
        set { self[AppNavigationCoordinatorKey.self] = newValue }
    }
}
