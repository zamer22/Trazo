import SwiftData
import SwiftUI

struct JoinClubSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentUserProfile) private var currentUserProfile
    @Environment(\.appNavigation) private var navigation

    @State private var inviteCode: String
    @State private var isJoining = false
    @State private var errorMessage: String?

    init(prefilledCode: String = "") {
        _inviteCode = State(initialValue: prefilledCode)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: TrazoSpacing.lg) {
                Text("Ingresa el código o abre un enlace de invitación para unirte a un Running Club.")
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textSecondary)

                VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                    Text("Código del club")
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)

                    TextField("Ej. RC-7X2K", text: $inviteCode)
                        .font(TrazoTypography.title())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding(TrazoSpacing.lg)
                        .background(TrazoColors.elevated.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.accentOrange)
                }

                if !SupabaseConfig.isConfigured {
                    Label("Modo local: solo clubs en este dispositivo o remoto cuando configures Supabase.", systemImage: "icloud")
                        .font(.caption2)
                        .foregroundStyle(TrazoColors.mutedTeal)
                }

                Spacer()

                TrazoButton(title: isJoining ? "Uniéndote..." : "Unirme al club", isEnabled: canJoin) {
                    Task { await join() }
                }
            }
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .navigationTitle("Unirse a un club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TrazoColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private var canJoin: Bool {
        !isJoining && !inviteCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func join() async {
        isJoining = true
        errorMessage = nil
        defer { isJoining = false }

        do {
            let club = try await ClubJoinService.join(
                inviteCode: inviteCode,
                profile: currentUserProfile,
                in: modelContext
            )
            navigation.openClub(club)
            dismiss()
        } catch JoinClubError.alreadyMember(let club) {
            navigation.openClub(club)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
