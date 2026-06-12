import Foundation

#if canImport(Supabase)
import Supabase
#endif

/// Lee clubs y mensajes remotos cuando Supabase está configurado.
/// Tablas esperadas: `clubs`, `club_messages` (ver `Supabase/community_schema.sql`).
@MainActor
final class CommunityRemoteService {
    static let shared = CommunityRemoteService()

    private init() {}

    func fetchClub(inviteCode: String) async throws -> RemoteClubDTO? {
        #if canImport(Supabase)
        guard let client = SupabaseClientProvider.shared else { return nil }

        let normalized = ClubJoinService.normalize(inviteCode)
        let clubs: [RemoteClubDTO] = try await client
            .from("clubs")
            .select()
            .eq("invite_code", value: normalized)
            .limit(1)
            .execute()
            .value

        return clubs.first
        #else
        return nil
        #endif
    }

    func fetchMessages(clubSlug: String, after date: Date?) async throws -> [RemoteClubMessageDTO] {
        #if canImport(Supabase)
        guard let client = SupabaseClientProvider.shared else { return [] }

        let messages: [RemoteClubMessageDTO] = try await client
            .from("club_messages")
            .select()
            .eq("club_slug", value: clubSlug)
            .order("created_at", ascending: true)
            .execute()
            .value

        guard let date else { return messages }
        return messages.filter { $0.timestamp > date }
        #else
        return []
        #endif
    }

    func sendMessage(
        clubSlug: String,
        senderName: String,
        text: String,
        isFromCurrentUser: Bool
    ) async throws {
        #if canImport(Supabase)
        guard let client = SupabaseClientProvider.shared else { return }

        struct InsertPayload: Encodable {
            let club_slug: String
            let sender_name: String
            let text: String
            let is_from_current_user: Bool
        }

        try await client
            .from("club_messages")
            .insert(
                InsertPayload(
                    club_slug: clubSlug,
                    sender_name: senderName,
                    text: text,
                    is_from_current_user: isFromCurrentUser
                )
            )
            .execute()
        #endif
    }
}
