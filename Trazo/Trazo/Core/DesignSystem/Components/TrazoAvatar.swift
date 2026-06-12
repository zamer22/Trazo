import SwiftUI

struct TrazoAvatar: View {
    let initials: String
    var color: Color = TrazoColors.routeTeal
    var size: CGFloat = 48

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.avatar, style: .continuous))
    }
}

#Preview {
    TrazoAvatar(initials: "DS")
        .padding()
        .background(TrazoColors.background)
}
