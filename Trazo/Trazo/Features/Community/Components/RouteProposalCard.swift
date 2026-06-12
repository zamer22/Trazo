import SwiftUI

struct RouteProposalCard: View {
    let proposal: RouteProposal
    let hasVoted: Bool
    let onVote: () -> Void

    var body: some View {
        TrazoCard {
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                        Text(proposal.title)
                            .font(TrazoTypography.headline())
                            .foregroundStyle(TrazoColors.textPrimary)

                        Text(proposal.destinationName)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.textSecondary)

                        Text("Por \(proposal.proposerName)")
                            .font(.caption2)
                            .foregroundStyle(TrazoColors.mutedTeal)
                    }

                    Spacer()

                    if proposal.isWinner {
                        Label("Ganador", systemImage: "trophy.fill")
                            .font(.caption2.bold())
                            .foregroundStyle(TrazoColors.accentOrange)
                    }
                }

                HStack(spacing: TrazoSpacing.lg) {
                    statItem(icon: "figure.run", value: proposal.formattedDistance)
                    statItem(icon: "clock", value: proposal.formattedDuration)
                    statItem(icon: "hand.thumbsup", value: "\(proposal.voteCount)")
                }

                if proposal.status == .open {
                    Button(action: onVote) {
                        Text(hasVoted ? "Tu voto ✓" : "Votar")
                            .font(TrazoTypography.caption())
                            .foregroundStyle(hasVoted ? TrazoColors.routeTeal : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TrazoSpacing.sm)
                            .background(hasVoted ? TrazoColors.routeTeal.opacity(0.15) : TrazoColors.routeTeal)
                            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func statItem(icon: String, value: String) -> some View {
        Label(value, systemImage: icon)
            .font(TrazoTypography.caption())
            .foregroundStyle(TrazoColors.textSecondary)
    }
}
