import SwiftUI

struct TrazoButton: View {
    enum Style {
        case primary
        case secondary
    }

    let title: String
    var style: Style = .primary
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TrazoTypography.headline())
                .foregroundStyle(foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, TrazoSpacing.lg)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: TrazoColors.routeTeal
        case .secondary: TrazoColors.surface
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: TrazoColors.textPrimary
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        TrazoButton(title: "Empezar a correr") {}
        TrazoButton(title: "Cancelar", style: .secondary) {}
    }
    .padding()
    .background(TrazoColors.background)
}
