import SwiftData
import SwiftUI

struct ProposeTrazoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.currentUserProfile) private var currentUserProfile

    @Bindable var club: RunningClub

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TrazoSpacing.lg) {
                    Text("Elige un Trazo para proponer al club. Los miembros podrán votar o usar la ruleta.")
                        .font(TrazoTypography.body())
                        .foregroundStyle(TrazoColors.textSecondary)

                    ForEach(TrazoProposalTemplate.presets) { template in
                        proposalOption(template)
                    }
                }
                .padding(TrazoSpacing.lg)
            }
            .background(TrazoColors.surface)
            .navigationTitle("Proponer Trazo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TrazoColors.surface, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }

    private func proposalOption(_ template: TrazoProposalTemplate) -> some View {
        Button {
            propose(template)
        } label: {
            TrazoCard {
                HStack {
                    VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                        Text(template.title)
                            .font(TrazoTypography.headline())
                            .foregroundStyle(TrazoColors.textPrimary)

                        Text(template.destinationName)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f km", template.distanceKm))
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.routeTeal)
                        Text("\(template.estimatedMinutes) min")
                            .font(.caption2)
                            .foregroundStyle(TrazoColors.mutedTeal)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(TrazoColors.mutedTeal)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func propose(_ template: TrazoProposalTemplate) {
        let proposerName = currentUserProfile?.displayName.nilIfEmpty ?? "Tú"
        CommunityRouteService.propose(
            template: template,
            club: club,
            proposerName: proposerName,
            in: modelContext
        )
        dismiss()
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
