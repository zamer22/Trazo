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

    private var colorScheme: ColorScheme {
        AppColorScheme(rawValue: appColorScheme)?.colorScheme ?? .light
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(colorScheme)
        }
        .modelContainer(for: UserProfile.self)
    }
}
