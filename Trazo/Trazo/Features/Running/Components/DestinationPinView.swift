import SwiftUI

struct DestinationPinView: View {
    let onDoubleTap: () -> Void

    var body: some View {
        VStack(spacing: TrazoSpacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(TrazoColors.accentOrange)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            Text("Doble tap para confirmar")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(TrazoColors.textPrimary)
                .padding(.horizontal, TrazoSpacing.sm)
                .padding(.vertical, TrazoSpacing.xs)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
        .onTapGesture(count: 2) {
            onDoubleTap()
        }
    }
}

#Preview {
    DestinationPinView(onDoubleTap: {})
}
