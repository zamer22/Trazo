import SwiftUI

/// Sección de leaderboard para incrustar dentro de la card del club fijado.
struct LeaderboardPreviewSection: View {
    let club: RunningClub

    private var topThree: [LeaderboardEntry] {
        Array(LeaderboardMockData.entries(for: club).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Label("Leaderboard", systemImage: "trophy.fill")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)

                Spacer()

                Text("Esta semana")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(TrazoColors.mutedTeal)
            }

            HStack(spacing: TrazoSpacing.md) {
                ForEach(Array(topThree.enumerated()), id: \.element.id) { index, entry in
                    previewItem(entry, rank: index + 1)
                }
            }
        }
    }

    private func previewItem(_ entry: LeaderboardEntry, rank: Int) -> some View {
        VStack(spacing: TrazoSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                TrazoAvatar(initials: entry.initials, color: entry.accent.color, size: 40)

                Text("\(rank)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(rankColor(rank))
                    .clipShape(Circle())
                    .offset(x: 4, y: -4)
            }

            Text(entry.isCurrentUser ? "Tú" : entry.name.split(separator: " ").first.map(String.init) ?? entry.name)
                .font(.caption2)
                .foregroundStyle(entry.isCurrentUser ? TrazoColors.routeTeal : TrazoColors.textSecondary)
                .lineLimit(1)

            Text(String(format: "%.0f km", entry.weeklyKm))
                .font(.caption2.bold())
                .foregroundStyle(TrazoColors.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: TrazoColors.accentOrange
        case 2: TrazoColors.mutedTeal
        default: TrazoColors.routeTeal
        }
    }
}
