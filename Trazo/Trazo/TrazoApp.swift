//
//  TrazoApp.swift
//  Trazo
//
//  Created by Diego Saldaña on 12/06/26.
//

import SwiftData
import SwiftUI

@main
struct TrazoApp: App {
    @AppStorage("appColorScheme") private var appColorScheme = AppColorScheme.light.rawValue
    @State private var navigation = AppNavigationCoordinator()

    private var colorScheme: ColorScheme {
        AppColorScheme(rawValue: appColorScheme)?.colorScheme ?? .light
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.appNavigation, navigation)
                .preferredColorScheme(colorScheme)
                .onOpenURL { url in
                    if let code = DeepLinkRouter.inviteCode(from: url) {
                        navigation.openJoinClub(code: code)
                    }
                }
        }
        .modelContainer(for: [
            UserProfile.self,
            RunningClub.self,
            ClubMember.self,
            ClubMessage.self,
            ClubInvitation.self,
            RouteProposal.self,
            RouteVote.self,
        ])
    }
}
