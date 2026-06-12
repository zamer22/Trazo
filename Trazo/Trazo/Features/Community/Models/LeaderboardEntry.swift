import Foundation

struct LeaderboardEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let initials: String
    let accent: ClubAccent
    let weeklyKm: Double
    let monthlyKm: Double
    let runCount: Int
    let streakDays: Int
    let isCurrentUser: Bool
}

enum LeaderboardMetric: String, CaseIterable, Identifiable {
    case weeklyKm = "Km semana"
    case monthlyKm = "Km mes"
    case runs = "Carreras"
    case streak = "Racha"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .weeklyKm, .monthlyKm: "figure.run"
        case .runs: "flag.checkered"
        case .streak: "flame.fill"
        }
    }
}

enum LeaderboardPeriod: String, CaseIterable, Identifiable {
    case week = "Semana"
    case month = "Mes"

    var id: String { rawValue }
}

enum LeaderboardMockData {
    static func entries(for club: RunningClub) -> [LeaderboardEntry] {
        let entries = samplesBySlug[club.slug] ?? genericEntries(for: club)
        return entries.sorted { $0.weeklyKm > $1.weeklyKm }
    }

    static func sorted(_ entries: [LeaderboardEntry], by metric: LeaderboardMetric, period _: LeaderboardPeriod) -> [LeaderboardEntry] {
        switch metric {
        case .weeklyKm:
            return entries.sorted { $0.weeklyKm > $1.weeklyKm }
        case .monthlyKm:
            return entries.sorted { $0.monthlyKm > $1.monthlyKm }
        case .runs:
            return entries.sorted { $0.runCount > $1.runCount }
        case .streak:
            return entries.sorted { $0.streakDays > $1.streakDays }
        }
    }

    static func value(for entry: LeaderboardEntry, metric: LeaderboardMetric, period _: LeaderboardPeriod) -> String {
        switch metric {
        case .weeklyKm:
            return String(format: "%.1f km", entry.weeklyKm)
        case .monthlyKm:
            return String(format: "%.1f km", entry.monthlyKm)
        case .runs:
            return "\(entry.runCount)"
        case .streak:
            return "\(entry.streakDays) días"
        }
    }

    private static let samplesBySlug: [String: [LeaderboardEntry]] = [
        CommunitySeedService.runningClubSlug: [
            LeaderboardEntry(id: "harry", name: "Harry Fettel", initials: "HF", accent: .teal, weeklyKm: 42.3, monthlyKm: 168.0, runCount: 6, streakDays: 12, isCurrentUser: false),
            LeaderboardEntry(id: "ana", name: "Ana Ruiz", initials: "AR", accent: .muted, weeklyKm: 38.7, monthlyKm: 152.4, runCount: 5, streakDays: 9, isCurrentUser: false),
            LeaderboardEntry(id: "current-user", name: "Tú", initials: "TÚ", accent: .teal, weeklyKm: 35.2, monthlyKm: 141.8, runCount: 5, streakDays: 7, isCurrentUser: true),
            LeaderboardEntry(id: "frank", name: "Frank Garcia", initials: "FG", accent: .orange, weeklyKm: 28.5, monthlyKm: 112.0, runCount: 4, streakDays: 5, isCurrentUser: false),
        ],
        "club-saturday": [
            LeaderboardEntry(id: "harry", name: "Harry Fettel", initials: "HF", accent: .teal, weeklyKm: 52.0, monthlyKm: 198.0, runCount: 7, streakDays: 14, isCurrentUser: false),
            LeaderboardEntry(id: "current-user", name: "Tú", initials: "TÚ", accent: .teal, weeklyKm: 44.1, monthlyKm: 176.5, runCount: 6, streakDays: 8, isCurrentUser: true),
        ],
        "club-park": [
            LeaderboardEntry(id: "frank", name: "Frank Garcia", initials: "FG", accent: .orange, weeklyKm: 31.0, monthlyKm: 124.0, runCount: 5, streakDays: 6, isCurrentUser: false),
            LeaderboardEntry(id: "current-user", name: "Tú", initials: "TÚ", accent: .teal, weeklyKm: 26.4, monthlyKm: 98.2, runCount: 4, streakDays: 4, isCurrentUser: true),
        ],
        "club-ruleta": [
            LeaderboardEntry(id: "ana", name: "Ana Ruiz", initials: "AR", accent: .muted, weeklyKm: 45.8, monthlyKm: 180.2, runCount: 6, streakDays: 11, isCurrentUser: false),
            LeaderboardEntry(id: "current-user", name: "Tú", initials: "TÚ", accent: .teal, weeklyKm: 39.0, monthlyKm: 155.0, runCount: 5, streakDays: 7, isCurrentUser: true),
        ],
    ]

    private static func genericEntries(for club: RunningClub) -> [LeaderboardEntry] {
        club.members.enumerated().map { index, member in
            let base = Double(30 - index * 5)
            return LeaderboardEntry(
                id: member.username,
                name: member.displayName,
                initials: member.initials,
                accent: member.accent,
                weeklyKm: max(8, base),
                monthlyKm: max(32, base * 4),
                runCount: max(2, 6 - index),
                streakDays: max(1, 10 - index * 2),
                isCurrentUser: member.isCurrentUser
            )
        }
    }
}
