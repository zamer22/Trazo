import Foundation
import SwiftData

@Model
final class RunningClub {
    @Attribute(.unique) var slug: String
    var name: String
    var initials: String
    var accentRaw: String
    var lastMessageText: String
    var lastMessageAt: Date
    var unreadCount: Int
    var inviteCode: String
    var isPinned: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ClubMember.club)
    var members: [ClubMember]

    @Relationship(deleteRule: .cascade, inverse: \ClubMessage.club)
    var messages: [ClubMessage]

    @Relationship(deleteRule: .cascade, inverse: \ClubInvitation.club)
    var invitations: [ClubInvitation]

    @Relationship(deleteRule: .cascade, inverse: \RouteProposal.club)
    var proposals: [RouteProposal]

    init(
        slug: String,
        name: String,
        initials: String,
        accent: ClubAccent,
        lastMessageText: String,
        lastMessageAt: Date,
        unreadCount: Int,
        inviteCode: String,
        isPinned: Bool,
        createdAt: Date = .now
    ) {
        self.slug = slug
        self.name = name
        self.initials = initials
        self.accentRaw = accent.rawValue
        self.lastMessageText = lastMessageText
        self.lastMessageAt = lastMessageAt
        self.unreadCount = unreadCount
        self.inviteCode = inviteCode
        self.isPinned = isPinned
        self.createdAt = createdAt
        self.members = []
        self.messages = []
        self.invitations = []
        self.proposals = []
    }

    var openProposals: [RouteProposal] {
        proposals
            .filter { $0.status == .open }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var resolvedWinner: RouteProposal? {
        proposals.first { $0.isWinner }
    }

    var accent: ClubAccent {
        get { ClubAccent(rawValue: accentRaw) ?? .teal }
        set { accentRaw = newValue.rawValue }
    }

    var memberCount: Int { members.count }

    var inviteLink: String {
        "https://trazo.app/join/\(inviteCode)"
    }

    var lastMessage: String { lastMessageText }

    var lastMessageTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastMessageAt, relativeTo: .now)
    }
}
