import Foundation
import SwiftData

@Model
final class ClubMessage {
    var senderName: String
    var text: String
    var timestamp: Date
    var isFromCurrentUser: Bool
    var club: RunningClub?

    init(
        senderName: String,
        text: String,
        timestamp: Date,
        isFromCurrentUser: Bool,
        club: RunningClub? = nil
    ) {
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.isFromCurrentUser = isFromCurrentUser
        self.club = club
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
}
