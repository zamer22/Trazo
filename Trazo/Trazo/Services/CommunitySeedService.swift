import Foundation
import SwiftData

enum CommunitySeedService {
    static let runningClubSlug = "club-running"

    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<RunningClub>()
        guard (try? context.fetchCount(descriptor)) == 0 else { return }

        seedSampleClubs(in: context)
        try? context.save()
    }

    private static func seedSampleClubs(in context: ModelContext) {
        let runningClub = RunningClub(
            slug: runningClubSlug,
            name: "Running Club",
            initials: "RC",
            accent: .orange,
            lastMessageText: "Propón un Trazo para el sábado...",
            lastMessageAt: .minutesAgo(4),
            unreadCount: 3,
            inviteCode: "RC-7X2K",
            isPinned: true
        )
        context.insert(runningClub)
        addMembers(
            to: runningClub,
            in: context,
            members: [
                ("Tú", "@tu.perfil", "TÚ", ClubAccent.teal, ClubMemberRole.owner, true),
                ("Ana Ruiz", "@ana.ruiz", "AR", .muted, .member, false),
                ("Harry Fettel", "@harry.run", "HF", .teal, .member, false),
                ("Frank Garcia", "@frank.g", "FG", .orange, .member, false),
            ]
        )
        addMessages(to: runningClub, in: context, messages: [
            ("Ana", "¿Trazo para el sábado?", .hoursAgo(2), false),
            ("Tú", "Propongo 8K por el parque 🏃", .hoursAgo(1.5), true),
            ("Harry", "Yo voto por Fundidora", .hoursAgo(1), false),
            ("Frank", "¿Activamos la ruleta? 🎲", .minutesAgo(4), false),
        ])
        seedProposals(for: runningClub, in: context)

        let saturdayClub = RunningClub(
            slug: "club-saturday",
            name: "Sábados 10K",
            initials: "S10",
            accent: .teal,
            lastMessageText: "¿Quién propone Trazo mañana?",
            lastMessageAt: .hoursAgo(3),
            unreadCount: 0,
            inviteCode: "S10-M4P9",
            isPinned: false
        )
        context.insert(saturdayClub)
        addMembers(to: saturdayClub, in: context, members: [
            ("Tú", "@tu.perfil", "TÚ", .teal, .owner, true),
            ("Harry Fettel", "@harry.run", "HF", .teal, .member, false),
        ])
        addMessages(to: saturdayClub, in: context, messages: [
            ("Harry", "¿Quién propone Trazo mañana?", .hoursAgo(3), false),
            ("Tú", "Puedo armar uno de 10K", .hoursAgo(2), true),
        ])

        let parkClub = RunningClub(
            slug: "club-park",
            name: "Parque Fundidora",
            initials: "PF",
            accent: .orange,
            lastMessageText: "Yo voto por el parque",
            lastMessageAt: .daysAgo(1),
            unreadCount: 0,
            inviteCode: "PF-K2L8",
            isPinned: false
        )
        context.insert(parkClub)
        addMembers(to: parkClub, in: context, members: [
            ("Tú", "@tu.perfil", "TÚ", .teal, .owner, true),
            ("Frank Garcia", "@frank.g", "FG", .orange, .member, false),
        ])
        addMessages(to: parkClub, in: context, messages: [
            ("Frank", "Yo voto por el parque", .daysAgo(1), false),
        ])

        let ruletaClub = RunningClub(
            slug: "club-ruleta",
            name: "Ruleta Runners",
            initials: "RR",
            accent: .muted,
            lastMessageText: "Ruleta activada 🎲",
            lastMessageAt: .daysAgo(1),
            unreadCount: 1,
            inviteCode: "RR-9QW3",
            isPinned: false
        )
        context.insert(ruletaClub)
        addMembers(to: ruletaClub, in: context, members: [
            ("Tú", "@tu.perfil", "TÚ", .teal, .owner, true),
            ("Ana Ruiz", "@ana.ruiz", "AR", .muted, .member, false),
        ])
        addMessages(to: ruletaClub, in: context, messages: [
            ("Ana", "Ruleta activada 🎲", .daysAgo(1), false),
            ("Tú", "¡Vamos con el Trazo del lago!", .daysAgo(1), true),
        ])
    }

    private static func addMembers(
        to club: RunningClub,
        in context: ModelContext,
        members: [(String, String, String, ClubAccent, ClubMemberRole, Bool)]
    ) {
        for (name, username, initials, accent, role, isCurrentUser) in members {
            let member = ClubMember(
                displayName: name,
                username: username,
                initials: initials,
                accent: accent,
                role: role,
                isCurrentUser: isCurrentUser,
                club: club
            )
            context.insert(member)
        }
    }

    private static func addMessages(
        to club: RunningClub,
        in context: ModelContext,
        messages: [(String, String, Date, Bool)]
    ) {
        for (sender, text, timestamp, isFromCurrentUser) in messages {
            let message = ClubMessage(
                senderName: sender,
                text: text,
                timestamp: timestamp,
                isFromCurrentUser: isFromCurrentUser,
                club: club
            )
            context.insert(message)
        }
    }

    private static func seedProposals(for club: RunningClub, in context: ModelContext) {
        let fundidora = RouteProposal(
            title: "8K Parque Fundidora",
            destinationName: "Parque Fundidora",
            destinationLatitude: 25.6782,
            destinationLongitude: -100.2843,
            distanceKm: 8.0,
            estimatedMinutes: 48,
            proposerName: "Ana",
            proposerExternalID: "ana",
            createdAt: .hoursAgo(1.2),
            club: club
        )
        context.insert(fundidora)
        context.insert(RouteVote(voterName: "Harry", voterExternalID: "harry", proposal: fundidora))
        context.insert(RouteVote(voterName: "Frank", voterExternalID: "frank", proposal: fundidora))

        let santaLucia = RouteProposal(
            title: "5K Paseo Santa Lucía",
            destinationName: "Paseo Santa Lucía",
            destinationLatitude: 25.6714,
            destinationLongitude: -100.3093,
            distanceKm: 5.2,
            estimatedMinutes: 32,
            proposerName: "Tú",
            proposerExternalID: CommunityRouteService.currentUserID,
            createdAt: .hoursAgo(1.4),
            club: club
        )
        context.insert(santaLucia)
        context.insert(RouteVote(voterName: "Ana", voterExternalID: "ana", proposal: santaLucia))
    }
}

private extension Date {
    static func hoursAgo(_ hours: Double) -> Date {
        Date().addingTimeInterval(-hours * 3600)
    }

    static func minutesAgo(_ minutes: Double) -> Date {
        Date().addingTimeInterval(-minutes * 60)
    }

    static func daysAgo(_ days: Double) -> Date {
        Date().addingTimeInterval(-days * 86400)
    }
}
