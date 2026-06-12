import Foundation
import SwiftData

enum ClubInvitationStatus: String, Codable {
    case pending
    case accepted
    case declined
}

@Model
final class ClubInvitation {
    var inviteeName: String
    var inviteeUsername: String
    var inviteeInitials: String
    var inviteeAccentRaw: String
    var inviteeExternalID: String
    var statusRaw: String
    var sentAt: Date
    var club: RunningClub?

    init(
        inviteeName: String,
        inviteeUsername: String,
        inviteeInitials: String,
        inviteeAccent: ClubAccent,
        inviteeExternalID: String,
        status: ClubInvitationStatus = .pending,
        sentAt: Date = .now,
        club: RunningClub? = nil
    ) {
        self.inviteeName = inviteeName
        self.inviteeUsername = inviteeUsername
        self.inviteeInitials = inviteeInitials
        self.inviteeAccentRaw = inviteeAccent.rawValue
        self.inviteeExternalID = inviteeExternalID
        self.statusRaw = status.rawValue
        self.sentAt = sentAt
        self.club = club
    }

    var inviteeAccent: ClubAccent {
        get { ClubAccent(rawValue: inviteeAccentRaw) ?? .teal }
        set { inviteeAccentRaw = newValue.rawValue }
    }

    var status: ClubInvitationStatus {
        get { ClubInvitationStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}
