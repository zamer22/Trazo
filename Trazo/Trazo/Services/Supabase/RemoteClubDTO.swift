import Foundation

struct RemoteClubDTO: Decodable, Sendable {
    let slug: String
    let name: String
    let initials: String
    let accentRaw: String
    let inviteCode: String
    let lastMessageText: String?
    let lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case slug
        case name
        case initials
        case accentRaw = "accent_raw"
        case inviteCode = "invite_code"
        case lastMessageText = "last_message_text"
        case lastMessageAt = "last_message_at"
    }
}

struct RemoteClubMessageDTO: Decodable, Sendable {
    let id: UUID
    let senderName: String
    let text: String
    let timestamp: Date
    let isFromCurrentUser: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case senderName = "sender_name"
        case text
        case timestamp = "created_at"
        case isFromCurrentUser = "is_from_current_user"
    }
}
