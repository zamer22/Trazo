import SwiftUI

enum AppColorScheme: String {
    case light
    case dark

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    var toggled: AppColorScheme {
        self == .dark ? .light : .dark
    }

    var toggleLabel: String {
        self == .dark ? "Modo claro" : "Modo oscuro"
    }

    var toggleIcon: String {
        self == .dark ? "sun.max.fill" : "moon.fill"
    }
}
