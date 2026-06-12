import SwiftData
import SwiftUI

struct InviteFriendsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var club: RunningClub

    @State private var searchText = ""
    @State private var didCopyCode = false

    private var filteredFriends: [InvitableFriend] {
        guard !searchText.isEmpty else { return InvitableFriend.samples }
        return InvitableFriend.samples.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.username.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.lg) {
                    inviteLinkCard
                    inviteCodeCard
                    friendsSection
                }
                .padding(TrazoSpacing.lg)
            }
            .background(TrazoColors.surface)
            .navigationTitle("Invitar amigos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TrazoColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar amigos")
        }
    }

    private var inviteLinkCard: some View {
        TrazoCard {
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                Label("Enlace de invitación", systemImage: "link")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)

                Text("Comparte este enlace para que tus amigos se unan a \(club.name).")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                Text(club.inviteLink)
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.routeTeal)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                ShareLink(item: club.inviteLink, subject: Text(club.name), message: Text(inviteMessage)) {
                    Label("Compartir enlace", systemImage: "square.and.arrow.up")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, TrazoSpacing.md)
                        .background(TrazoColors.routeTeal)
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                }
            }
        }
    }

    private var inviteCodeCard: some View {
        TrazoCard {
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                Text("Código del club")
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)

                HStack {
                    Text(club.inviteCode)
                        .font(TrazoTypography.title())
                        .foregroundStyle(TrazoColors.textPrimary)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = club.inviteCode
                        didCopyCode = true
                    } label: {
                        Label(didCopyCode ? "Copiado" : "Copiar", systemImage: didCopyCode ? "checkmark" : "doc.on.doc")
                            .font(TrazoTypography.caption())
                    }
                    .foregroundStyle(TrazoColors.routeTeal)
                }
            }
        }
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Amigos en Trazo")
                .font(TrazoTypography.headline())
                .foregroundStyle(TrazoColors.textPrimary)

            ForEach(filteredFriends) { friend in
                friendRow(friend)
            }
        }
    }

    private func friendRow(_ friend: InvitableFriend) -> some View {
        HStack(spacing: TrazoSpacing.md) {
            TrazoAvatar(initials: friend.initials, color: friend.accent.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.name)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textPrimary)
                Text(friend.username)
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
            }

            Spacer()

            if isInvited(friend) {
                Text("Invitado")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.routeTeal)
            } else {
                Button("Invitar") {
                    sendInvitation(to: friend)
                }
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.routeTeal)
            }
        }
        .padding(.vertical, TrazoSpacing.sm)
    }

    private func isInvited(_ friend: InvitableFriend) -> Bool {
        club.invitations.contains {
            $0.inviteeExternalID == friend.id && $0.status == .pending
        }
    }

    private func sendInvitation(to friend: InvitableFriend) {
        guard !isInvited(friend) else { return }

        let invitation = ClubInvitation(
            inviteeName: friend.name,
            inviteeUsername: friend.username,
            inviteeInitials: friend.initials,
            inviteeAccent: friend.accent,
            inviteeExternalID: friend.id,
            status: .pending,
            club: club
        )
        modelContext.insert(invitation)
        try? modelContext.save()
    }

    private var inviteMessage: String {
        "Únete a \(club.name) en Trazo. Código: \(club.inviteCode)\n\(club.inviteLink)"
    }
}

private struct InvitableFriend: Identifiable {
    let id: String
    let name: String
    let username: String
    let initials: String
    let accent: ClubAccent

    static let samples: [InvitableFriend] = [
        InvitableFriend(id: "harry", name: "Harry Fettel", username: "@harry.run", initials: "HF", accent: .teal),
        InvitableFriend(id: "frank", name: "Frank Garcia", username: "@frank.g", initials: "FG", accent: .orange),
        InvitableFriend(id: "ana", name: "Ana Ruiz", username: "@ana.ruiz", initials: "AR", accent: .muted),
        InvitableFriend(id: "luis", name: "Luis Torres", username: "@luis.t", initials: "LT", accent: .teal),
    ]
}
