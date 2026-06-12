import Foundation
import SwiftData

enum RouteProposalStatus: String, Codable {
    case open
    case resolved
}

@Model
final class RouteProposal {
    var title: String
    var destinationName: String
    var destinationLatitude: Double
    var destinationLongitude: Double
    var distanceKm: Double
    var estimatedMinutes: Int
    var proposerName: String
    var proposerExternalID: String
    var statusRaw: String
    var isWinner: Bool
    var createdAt: Date
    var club: RunningClub?

    @Relationship(deleteRule: .cascade, inverse: \RouteVote.proposal)
    var votes: [RouteVote]

    init(
        title: String,
        destinationName: String,
        destinationLatitude: Double,
        destinationLongitude: Double,
        distanceKm: Double,
        estimatedMinutes: Int,
        proposerName: String,
        proposerExternalID: String,
        status: RouteProposalStatus = .open,
        isWinner: Bool = false,
        createdAt: Date = .now,
        club: RunningClub? = nil
    ) {
        self.title = title
        self.destinationName = destinationName
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.distanceKm = distanceKm
        self.estimatedMinutes = estimatedMinutes
        self.proposerName = proposerName
        self.proposerExternalID = proposerExternalID
        self.statusRaw = status.rawValue
        self.isWinner = isWinner
        self.createdAt = createdAt
        self.club = club
        self.votes = []
    }

    var status: RouteProposalStatus {
        get { RouteProposalStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }

    var voteCount: Int { votes.count }

    var formattedDistance: String {
        String(format: "%.1f km", distanceKm)
    }

    var formattedDuration: String {
        "\(estimatedMinutes) min"
    }
}
