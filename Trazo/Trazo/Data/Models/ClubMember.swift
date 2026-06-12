import Foundation
import SwiftData

enum ClubMemberRole: String, Codable {
    case owner
    case member
}

@Model
final class ClubMember {
    var displayName: String
    var username: String
    var initials: String
    var accentRaw: String
    var roleRaw: String
    var isCurrentUser: Bool
    var joinedAt: Date
    var club: RunningClub?

    init(
        displayName: String,
        username: String,
        initials: String,
        accent: ClubAccent,
        role: ClubMemberRole,
        isCurrentUser: Bool,
        joinedAt: Date = .now,
        club: RunningClub? = nil
    ) {
        self.displayName = displayName
        self.username = username
        self.initials = initials
        self.accentRaw = accent.rawValue
        self.roleRaw = role.rawValue
        self.isCurrentUser = isCurrentUser
        self.joinedAt = joinedAt
        self.club = club
    }

    var accent: ClubAccent {
        get { ClubAccent(rawValue: accentRaw) ?? .teal }
        set { accentRaw = newValue.rawValue }
    }

    var role: ClubMemberRole {
        get { ClubMemberRole(rawValue: roleRaw) ?? .member }
        set { roleRaw = newValue.rawValue }
    }
}
