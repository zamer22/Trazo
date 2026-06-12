import SwiftData
import SwiftUI

struct CreateClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentUserProfile) private var currentUserProfile

    @State private var clubName = ""
    @State private var createdClub: RunningClub?

    var body: some View {
        NavigationStack {
            Group {
                if let createdClub {
                    createdState(club: createdClub)
                } else {
                    formState
                }
            }
            .background(TrazoColors.surface)
            .navigationTitle("Nuevo club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TrazoColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var formState: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.lg) {
            Text("Crea un Running Club para proponer Trazos, votar y correr con amigos.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)

            VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                Text("Nombre del club")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                TextField("Ej. Run MTY", text: $clubName)
                    .font(TrazoTypography.body())
                    .padding(TrazoSpacing.lg)
                    .background(TrazoColors.elevated.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            }

            Spacer()

            TrazoButton(title: "Crear club", isEnabled: !clubName.trimmingCharacters(in: .whitespaces).isEmpty) {
                createdClub = persistClub(from: clubName)
            }
        }
        .padding(TrazoSpacing.lg)
    }

    private func createdState(club: RunningClub) -> some View {
        VStack(spacing: TrazoSpacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(TrazoColors.routeTeal)

            Text("\(club.name) está listo")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)

            Text("Invita amigos con tu código o enlace para empezar a proponer Trazos.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)

            TrazoCard {
                VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                    Text("Código: \(club.inviteCode)")
                        .font(TrazoTypography.headline())
                        .foregroundStyle(TrazoColors.textPrimary)

                    ShareLink(item: club.inviteLink, subject: Text(club.name)) {
                        Label("Compartir invitación", systemImage: "square.and.arrow.up")
                            .font(TrazoTypography.headline())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, TrazoSpacing.md)
                            .background(TrazoColors.routeTeal)
                            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                    }
                }
            }

            Spacer()

            TrazoButton(title: "Ir al club") {
                dismiss()
            }
        }
        .padding(TrazoSpacing.lg)
    }

    private func persistClub(from name: String) -> RunningClub {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let initials = String(trimmed.prefix(2)).uppercased()
        let code = "CL-\(String(UUID().uuidString.prefix(4)).uppercased())"
        let displayName = currentUserProfile?.displayName.nilIfEmpty ?? "Tú"
        let username = displayName == "Tú" ? "@tu.perfil" : "@\(displayName.lowercased().replacingOccurrences(of: " ", with: "."))"

        let club = RunningClub(
            slug: UUID().uuidString,
            name: trimmed,
            initials: initials.isEmpty ? "CL" : initials,
            accent: ClubAccent.allCases.randomElement() ?? .teal,
            lastMessageText: "Club creado. ¡Invita amigos!",
            lastMessageAt: .now,
            unreadCount: 0,
            inviteCode: code,
            isPinned: false
        )
        modelContext.insert(club)

        let owner = ClubMember(
            displayName: displayName,
            username: username,
            initials: String(displayName.prefix(2)).uppercased(),
            accent: .teal,
            role: .owner,
            isCurrentUser: true,
            club: club
        )
        modelContext.insert(owner)

        let welcome = ClubMessage(
            senderName: "Trazo",
            text: "¡Bienvenido al club! Invita amigos para empezar.",
            timestamp: .now,
            isFromCurrentUser: false,
            club: club
        )
        modelContext.insert(welcome)

        try? modelContext.save()
        return club
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
