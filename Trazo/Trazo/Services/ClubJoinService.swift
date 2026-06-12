import Foundation
import SwiftData

enum JoinClubError: LocalizedError {
    case clubNotFound
    case alreadyMember(RunningClub)

    var errorDescription: String? {
        switch self {
        case .clubNotFound:
            "No encontramos un club con ese código. Revisa el enlace o pídele otro a tu amigo."
        case .alreadyMember(let club):
            "Ya eres miembro de \(club.name)."
        }
    }
}

enum ClubJoinService {
    static func join(
        inviteCode: String,
        profile: UserProfile?,
        in context: ModelContext
    ) async throws -> RunningClub {
        let normalized = normalize(inviteCode)

        if let localClub = try findLocalClub(inviteCode: normalized, in: context) {
            if localClub.members.contains(where: \.isCurrentUser) {
                throw JoinClubError.alreadyMember(localClub)
            }
            addCurrentUser(to: localClub, profile: profile, in: context)
            try context.save()
            return localClub
        }

        if let remoteClub = try await CommunityRemoteService.shared.fetchClub(inviteCode: normalized) {
            let club = importRemoteClub(remoteClub, in: context)
            addCurrentUser(to: club, profile: profile, in: context)
            try context.save()
            return club
        }

        throw JoinClubError.clubNotFound
    }

    static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func findLocalClub(inviteCode: String, in context: ModelContext) throws -> RunningClub? {
        let descriptor = FetchDescriptor<RunningClub>()
        let clubs = try context.fetch(descriptor)
        return clubs.first { normalize($0.inviteCode) == inviteCode }
    }

    private static func addCurrentUser(
        to club: RunningClub,
        profile: UserProfile?,
        in context: ModelContext
    ) {
        let displayName = profile?.displayName.nilIfEmpty ?? "Tú"
        let username = displayName == "Tú"
            ? "@tu.perfil"
            : "@\(displayName.lowercased().replacingOccurrences(of: " ", with: "."))"

        let member = ClubMember(
            displayName: displayName,
            username: username,
            initials: String(displayName.prefix(2)).uppercased(),
            accent: .teal,
            role: .member,
            isCurrentUser: true,
            club: club
        )
        context.insert(member)

        let welcome = ClubMessage(
            senderName: "Trazo",
            text: "Te uniste a \(club.name). ¡A proponer Trazos!",
            timestamp: .now,
            isFromCurrentUser: false,
            club: club
        )
        context.insert(welcome)
        club.lastMessageText = welcome.text
        club.lastMessageAt = .now
    }

    private static func importRemoteClub(_ remote: RemoteClubDTO, in context: ModelContext) -> RunningClub {
        let club = RunningClub(
            slug: remote.slug,
            name: remote.name,
            initials: remote.initials,
            accent: ClubAccent(rawValue: remote.accentRaw) ?? .teal,
            lastMessageText: remote.lastMessageText ?? "Club remoto",
            lastMessageAt: remote.lastMessageAt ?? .now,
            unreadCount: 0,
            inviteCode: remote.inviteCode,
            isPinned: false
        )
        context.insert(club)
        return club
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
