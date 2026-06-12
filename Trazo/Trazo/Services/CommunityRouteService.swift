import Foundation
import SwiftData

enum CommunityRouteService {
    static let currentUserID = "current-user"

    static func propose(
        template: TrazoProposalTemplate,
        club: RunningClub,
        proposerName: String,
        in context: ModelContext
    ) {
        let proposal = RouteProposal(
            title: template.title,
            destinationName: template.destinationName,
            destinationLatitude: template.latitude,
            destinationLongitude: template.longitude,
            distanceKm: template.distanceKm,
            estimatedMinutes: template.estimatedMinutes,
            proposerName: proposerName,
            proposerExternalID: currentUserID,
            club: club
        )
        context.insert(proposal)

        postSystemMessage(
            "\(proposerName) propuso «\(template.title)» (\(proposal.formattedDistance))",
            club: club,
            in: context
        )
        try? context.save()
    }

    static func castVote(
        for proposal: RouteProposal,
        club: RunningClub,
        voterName: String,
        in context: ModelContext
    ) {
        guard proposal.status == .open else { return }

        for openProposal in club.proposals where openProposal.status == .open {
            openProposal.votes.removeAll { $0.voterExternalID == currentUserID }
        }

        let vote = RouteVote(
            voterName: voterName,
            voterExternalID: currentUserID,
            proposal: proposal
        )
        context.insert(vote)

        postSystemMessage(
            "\(voterName) votó por «\(proposal.title)»",
            club: club,
            in: context
        )
        try? context.save()
    }

    static func runRoulette(
        club: RunningClub,
        in context: ModelContext
    ) -> RouteProposal? {
        let candidates = rouletteCandidates(for: club)
        guard let winner = candidates.randomElement() else { return nil }

        let winnerID = winner.persistentModelID
        for proposal in club.proposals where proposal.status == .open {
            proposal.status = .resolved
            proposal.isWinner = proposal.persistentModelID == winnerID
        }

        postSystemMessage(
            "🎲 Ruleta: ganó «\(winner.title)» (\(winner.formattedDistance))",
            club: club,
            in: context
        )
        try? context.save()
        return winner
    }

    static func rouletteCandidates(for club: RunningClub) -> [RouteProposal] {
        let open = club.proposals.filter { $0.status == .open }
        let withVotes = open.filter { !$0.votes.isEmpty }
        return withVotes.isEmpty ? open : withVotes
    }

    static func userVote(in club: RunningClub) -> RouteProposal? {
        club.proposals.first { proposal in
            proposal.votes.contains { $0.voterExternalID == currentUserID }
        }
    }

    static func hasUserVoted(for proposal: RouteProposal) -> Bool {
        proposal.votes.contains { $0.voterExternalID == currentUserID }
    }

    private static func postSystemMessage(
        _ text: String,
        club: RunningClub,
        in context: ModelContext
    ) {
        let message = ClubMessage(
            senderName: "Trazo",
            text: text,
            timestamp: .now,
            isFromCurrentUser: false,
            club: club
        )
        context.insert(message)
        club.lastMessageText = text
        club.lastMessageAt = .now
    }
}

struct TrazoProposalTemplate: Identifiable {
    let id: String
    let title: String
    let destinationName: String
    let latitude: Double
    let longitude: Double
    let distanceKm: Double
    let estimatedMinutes: Int

    static let presets: [TrazoProposalTemplate] = [
        TrazoProposalTemplate(
            id: "fundidora",
            title: "8K Parque Fundidora",
            destinationName: "Parque Fundidora",
            latitude: 25.6782,
            longitude: -100.2843,
            distanceKm: 8.0,
            estimatedMinutes: 48
        ),
        TrazoProposalTemplate(
            id: "santa-lucia",
            title: "5K Paseo Santa Lucía",
            destinationName: "Paseo Santa Lucía",
            latitude: 25.6714,
            longitude: -100.3093,
            distanceKm: 5.2,
            estimatedMinutes: 32
        ),
        TrazoProposalTemplate(
            id: "valle",
            title: "12K Valle Oriente",
            destinationName: "Valle Oriente",
            latitude: 25.6512,
            longitude: -100.3584,
            distanceKm: 12.0,
            estimatedMinutes: 72
        ),
        TrazoProposalTemplate(
            id: "chipinque",
            title: "10K Chipinque",
            destinationName: "Chipinque",
            latitude: 25.6106,
            longitude: -100.3565,
            distanceKm: 10.5,
            estimatedMinutes: 68
        ),
    ]
}

extension RoutePlan {
    func asProposalTemplate(title: String? = nil) -> TrazoProposalTemplate {
        TrazoProposalTemplate(
            id: id.uuidString,
            title: title ?? "\(String(format: "%.1f", distanceKm))K \(destinationName)",
            destinationName: destinationName,
            latitude: destinationLatitude,
            longitude: destinationLongitude,
            distanceKm: distanceKm,
            estimatedMinutes: estimatedMinutes
        )
    }
}
