import Foundation
import SwiftData

/// Punto de extensión para Supabase Realtime en mensajes de club.
/// Activar suscripción cuando el backend esté configurado (`community_schema.sql`).
@MainActor
final class CommunityRealtimeService {
    static let shared = CommunityRealtimeService()

    private init() {}

    func subscribe(
        clubSlug: String,
        modelContext: ModelContext,
        club: RunningClub
    ) async {
        guard SupabaseConfig.isConfigured else { return }
        // TODO: suscribirse a `club_messages` vía Supabase Realtime.
        _ = (clubSlug, modelContext, club)
    }

    func unsubscribe() async {}
}
