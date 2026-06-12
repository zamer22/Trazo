import SwiftUI

struct CommunityHomeView: View {
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: TrazoSpacing.lg) {
                TrazoSearchBar(text: $searchText)

                ScrollView {
                    LazyVStack(spacing: TrazoSpacing.md) {
                        pinnedClub

                        ForEach(MockChat.samples) { chat in
                            chatRow(chat)
                        }
                    }
                }
            }
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.background)
            .navigationTitle("Comunidad")
        }
    }

    private var pinnedClub: some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.md) {
                TrazoAvatar(initials: "RC", color: TrazoColors.accentOrange)

                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text("Running Club")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)

                    Text("Propón una ruta para el sábado...")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: TrazoSpacing.xs) {
                    Text("4 m")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)

                    Text("3")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(TrazoColors.routeTeal)
                        .clipShape(Circle())
                }
            }
        }
    }

    private func chatRow(_ chat: MockChat) -> some View {
        HStack(spacing: TrazoSpacing.md) {
            TrazoAvatar(initials: chat.initials, color: chat.color)

            VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                Text(chat.name)
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)

                Text(chat.lastMessage)
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(chat.time)
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)
        }
        .padding(.vertical, TrazoSpacing.sm)
    }
}

private struct MockChat: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let lastMessage: String
    let time: String
    let color: Color

    static let samples: [MockChat] = [
        MockChat(name: "Harry Fettel", initials: "HF", lastMessage: "¿Quién propone ruta mañana?", time: "9:31", color: TrazoColors.routeTeal),
        MockChat(name: "Frank Garcia", initials: "FG", lastMessage: "Yo voto por el parque", time: "Ayer", color: TrazoColors.accentOrange),
        MockChat(name: "Ana Ruiz", initials: "AR", lastMessage: "Ruleta activada 🎲", time: "Ayer", color: TrazoColors.mutedTeal),
    ]
}

#Preview {
    CommunityHomeView()
}
