import SwiftUI

struct FeaturePlaceholderView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: TrazoSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(TrazoColors.routeTeal)

            Text(title)
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)

            Text(subtitle)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, TrazoSpacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrazoColors.background)
    }
}
