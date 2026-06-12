import SwiftUI

enum TrazoColors {
    // MARK: - Brand

    static let accentOrange = Color.adaptive(
        light: Color(hex: 0xDD6A3D),
        dark: Color(hex: 0xCF633C)
    )

    static let routeTeal = Color.adaptive(
        light: Color(hex: 0x597E90),
        dark: Color(hex: 0x87B2B8)
    )

    static let mutedTeal = Color.adaptive(
        light: Color(hex: 0xA1B2C4),
        dark: Color(hex: 0x7A97A5)
    )

    // MARK: - Surfaces

    static let surface = Color.adaptive(
        light: Color(hex: 0xF0EEEA),
        dark: Color(hex: 0x212D35)
    )

    static let background = Color.adaptive(
        light: Color(hex: 0xFAFAF8),
        dark: Color(hex: 0x121214)
    )

    static let elevated = Color.adaptive(
        light: Color(hex: 0xFFFFFF),
        dark: Color(hex: 0x1A1F26)
    )

    // MARK: - Text

    static let textPrimary = Color.adaptive(
        light: Color(hex: 0x1A1F26),
        dark: Color(hex: 0xF5F5F3)
    )

    static let textSecondary = Color.adaptive(
        light: Color(hex: 0x597E90),
        dark: Color(hex: 0x7A97A5)
    )

    // MARK: - Chat / Community

    static let bubbleOutgoing = Color.adaptive(
        light: Color(hex: 0x597E90),
        dark: Color(hex: 0x3D6B8C)
    )

    static let bubbleIncoming = Color.adaptive(
        light: Color(hex: 0xF0EEEA),
        dark: Color(hex: 0x212D35)
    )

    static let tabActive = Color.adaptive(
        light: Color(hex: 0x597E90),
        dark: Color(hex: 0x87B2B8)
    )
}

private extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }

    init(hex: UInt, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
