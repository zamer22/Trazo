import SwiftUI

enum TrazoBottomChromeMetrics {
    static let searchZoneHeight: CGFloat = 76
    static let tabBarZoneHeight: CGFloat = 100
}

struct TrazoBottomChromeBackground: View {
    var body: some View {
        GeometryReader { geometry in
            let chromeHeight = TrazoBottomChromeMetrics.searchZoneHeight
                + TrazoBottomChromeMetrics.tabBarZoneHeight
                + geometry.safeAreaInsets.bottom

            UnevenRoundedRectangle(
                topLeadingRadius: TrazoRadius.lg,
                topTrailingRadius: TrazoRadius.lg
            )
            .fill(TrazoColors.surface)
            .frame(height: chromeHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

extension View {
    func trazoBottomChromeBackground() -> some View {
        background(alignment: .top) {
            TrazoBottomChromeBackground()
        }
    }
}

struct TrazoBottomSearchBar: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        HStack(spacing: TrazoSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TrazoColors.textSecondary)

            TextField(placeholder, text: $text)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TrazoColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
        .background(TrazoColors.elevated.opacity(0.5))
        .clipShape(Capsule())
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.top, TrazoSpacing.sm + 5 + TrazoSpacing.sm)
        .padding(.bottom, TrazoSpacing.sm + 10)
        .frame(height: TrazoBottomChromeMetrics.searchZoneHeight)
        .frame(maxWidth: .infinity)
        .trazoBottomChromeBackground()
    }
}

struct TrazoBottomSearchButton: View {
    let placeholder: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: TrazoSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(TrazoColors.textSecondary)

                Text(placeholder)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, TrazoSpacing.lg)
            .padding(.vertical, TrazoSpacing.md)
            .background(TrazoColors.elevated.opacity(0.5))
            .clipShape(Capsule())
            .padding(.horizontal, TrazoSpacing.lg)
        }
        .buttonStyle(.plain)
        .padding(.top, TrazoSpacing.sm + 5 + TrazoSpacing.sm)
        .padding(.bottom, TrazoSpacing.sm + 10)
        .frame(height: TrazoBottomChromeMetrics.searchZoneHeight)
        .frame(maxWidth: .infinity)
        .trazoBottomChromeBackground()
    }
}
