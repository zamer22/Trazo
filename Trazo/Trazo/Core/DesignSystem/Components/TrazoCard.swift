import SwiftUI

struct TrazoCard<Content: View>: View {
    var content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.lg, style: .continuous))
    }
}

struct TrazoStatCard: View {
    let label: String
    let value: String

    var body: some View {
        TrazoCard {
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
        }
    }
}

#Preview {
    TrazoStatCard(label: "Distancia", value: "12.5 KM")
        .padding()
        .background(TrazoColors.background)
}
