import SwiftUI

enum ClubAccent: String, CaseIterable, Codable {
    case orange
    case teal
    case muted

    var color: Color {
        switch self {
        case .orange: TrazoColors.accentOrange
        case .teal: TrazoColors.routeTeal
        case .muted: TrazoColors.mutedTeal
        }
    }
}
