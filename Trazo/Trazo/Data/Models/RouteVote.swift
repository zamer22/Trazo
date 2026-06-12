import Foundation
import SwiftData

@Model
final class RouteVote {
    var voterName: String
    var voterExternalID: String
    var createdAt: Date
    var proposal: RouteProposal?

    init(
        voterName: String,
        voterExternalID: String,
        createdAt: Date = .now,
        proposal: RouteProposal? = nil
    ) {
        self.voterName = voterName
        self.voterExternalID = voterExternalID
        self.createdAt = createdAt
        self.proposal = proposal
    }
}
