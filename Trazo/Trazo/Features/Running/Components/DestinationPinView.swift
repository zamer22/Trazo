import SwiftUI

struct DestinationPinView: View {
    let onDoubleTap: () -> Void

    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 36))
            .foregroundStyle(TrazoColors.accentOrange)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            .onTapGesture(count: 2) {
                onDoubleTap()
            }
    }
}

#Preview {
    DestinationPinView(onDoubleTap: {})
}
