import SwiftUI

struct TrazoSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Buscar"

    var body: some View {
        HStack(spacing: TrazoSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TrazoColors.textSecondary)

            TextField(placeholder, text: $text)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)
        }
        .padding(.horizontal, TrazoSpacing.lg)
        .padding(.vertical, TrazoSpacing.md)
        .background(TrazoColors.surface)
        .clipShape(Capsule())
    }
}

#Preview {
    @Previewable @State var query = ""
    TrazoSearchBar(text: $query)
        .padding()
        .background(TrazoColors.background)
}
