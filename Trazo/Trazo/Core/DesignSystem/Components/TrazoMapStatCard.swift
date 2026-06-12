import SwiftUI

struct TrazoMapStatCard: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text(label)
                .font(TrazoTypography.statLabel())
                .foregroundStyle(TrazoColors.textSecondary)

            Text(value)
                .font(TrazoTypography.statValue())
                .foregroundStyle(TrazoColors.textPrimary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TrazoSpacing.lg)
        .background(.ultraThinMaterial)
        .background(TrazoColors.surface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.lg, style: .continuous))
    }
}
