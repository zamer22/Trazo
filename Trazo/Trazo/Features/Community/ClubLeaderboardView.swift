import SwiftUI

struct ClubLeaderboardView: View {
    let club: RunningClub

    @State private var period: LeaderboardPeriod = .week
    @State private var metric: LeaderboardMetric = .weeklyKm

    private var rankedEntries: [LeaderboardEntry] {
        LeaderboardMockData.sorted(
            LeaderboardMockData.entries(for: club),
            by: metric,
            period: period
        )
    }

    private var currentUserRank: Int? {
        guard let index = rankedEntries.firstIndex(where: \.isCurrentUser) else { return nil }
        return index + 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TrazoSpacing.lg) {
                filters
                podium
                rankingsList
            }
            .padding(TrazoSpacing.lg)
            .padding(.bottom, TrazoSpacing.xl)
        }
        .background(TrazoColors.background)
        .navigationTitle("Leaderboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
    }

    private var filters: some View {
        VStack(spacing: TrazoSpacing.md) {
            Picker("Periodo", selection: $period) {
                ForEach(LeaderboardPeriod.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TrazoSpacing.sm) {
                    ForEach(LeaderboardMetric.allCases) { item in
                        Button {
                            metric = item
                        } label: {
                            Label(item.rawValue, systemImage: item.icon)
                                .font(TrazoTypography.caption())
                                .foregroundStyle(metric == item ? .white : TrazoColors.textSecondary)
                                .padding(.horizontal, TrazoSpacing.md)
                                .padding(.vertical, TrazoSpacing.sm)
                                .background(metric == item ? TrazoColors.routeTeal : TrazoColors.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var podium: some View {
        HStack(alignment: .bottom, spacing: TrazoSpacing.md) {
            if rankedEntries.count > 1 {
                podiumSpot(rankedEntries[1], rank: 2, height: 88)
            }
            if let first = rankedEntries.first {
                podiumSpot(first, rank: 1, height: 108)
            }
            if rankedEntries.count > 2 {
                podiumSpot(rankedEntries[2], rank: 3, height: 72)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TrazoSpacing.md)
    }

    private func podiumSpot(_ entry: LeaderboardEntry, rank: Int, height: CGFloat) -> some View {
        VStack(spacing: TrazoSpacing.sm) {
            TrazoAvatar(initials: entry.initials, color: entry.accent.color, size: rank == 1 ? 52 : 44)

            Text(entry.isCurrentUser ? "Tú" : entry.name.components(separatedBy: " ").first ?? entry.name)
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textPrimary)
                .lineLimit(1)

            Text(LeaderboardMockData.value(for: entry, metric: metric, period: period))
                .font(.caption2.bold())
                .foregroundStyle(TrazoColors.routeTeal)

            Text(rankLabel(rank))
                .font(TrazoTypography.statValue())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(rankColor(rank))
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    private var rankingsList: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            HStack {
                Text("Clasificación")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)

                Spacer()

                if let currentUserRank {
                    Text("Tu puesto: #\(currentUserRank)")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.routeTeal)
                }
            }

            ForEach(Array(rankedEntries.enumerated()), id: \.element.id) { index, entry in
                rankingRow(entry, rank: index + 1)
            }
        }
    }

    private func rankingRow(_ entry: LeaderboardEntry, rank: Int) -> some View {
        HStack(spacing: TrazoSpacing.md) {
            Text("\(rank)")
                .font(TrazoTypography.headline())
                .foregroundStyle(rank <= 3 ? rankColor(rank) : TrazoColors.textSecondary)
                .frame(width: 24)

            TrazoAvatar(initials: entry.initials, color: entry.accent.color, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.isCurrentUser ? "Tú" : entry.name)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textPrimary)

                Text("\(entry.runCount) carreras · racha \(entry.streakDays)d")
                    .font(.caption2)
                    .foregroundStyle(TrazoColors.mutedTeal)
            }

            Spacer()

            Text(LeaderboardMockData.value(for: entry, metric: metric, period: period))
                .font(TrazoTypography.headline())
                .foregroundStyle(TrazoColors.routeTeal)
        }
        .padding(TrazoSpacing.md)
        .background(entry.isCurrentUser ? TrazoColors.routeTeal.opacity(0.08) : TrazoColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: TrazoColors.accentOrange
        case 2: TrazoColors.mutedTeal
        case 3: TrazoColors.routeTeal
        default: TrazoColors.surface
        }
    }

    private func rankLabel(_ rank: Int) -> String {
        switch rank {
        case 1: "1°"
        case 2: "2°"
        case 3: "3°"
        default: "\(rank)°"
        }
    }
}
