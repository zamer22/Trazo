import SwiftData
import SwiftUI

struct TrazoRouletteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var club: RunningClub

    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var winner: RouteProposal?

    private var candidates: [RouteProposal] {
        CommunityRouteService.rouletteCandidates(for: club)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TrazoSpacing.xl) {
                    Text("¿No hay acuerdo? La ruleta elige el Trazo del día.")
                        .font(TrazoTypography.body())
                        .foregroundStyle(TrazoColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    rouletteWheel

                    if let winner {
                        resultCard(winner)
                        TrazoButton(title: "Listo") { dismiss() }
                    } else {
                        TrazoButton(
                            title: isSpinning ? "Girando..." : "Girar ruleta",
                            isEnabled: !isSpinning && candidates.count >= 2
                        ) {
                            spin()
                        }
                    }
                }
                .padding(TrazoSpacing.lg)
            }
            .background(TrazoColors.surface)
            .navigationTitle("Ruleta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(TrazoColors.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationBackground(TrazoColors.surface)
        .presentationDragIndicator(.visible)
    }

    private func resultCard(_ winner: RouteProposal) -> some View {
        TrazoCard {
            VStack(spacing: TrazoSpacing.sm) {
                Label("Trazo elegido", systemImage: "trophy.fill")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.accentOrange)

                Text(winner.title)
                    .font(TrazoTypography.headline())
                    .foregroundStyle(TrazoColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text("\(winner.formattedDistance) · \(winner.formattedDuration)")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var rouletteWheel: some View {
        VStack(spacing: TrazoSpacing.md) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.title3)
                .foregroundStyle(TrazoColors.accentOrange)

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                TrazoColors.routeTeal,
                                TrazoColors.mutedTeal,
                                TrazoColors.accentOrange,
                                TrazoColors.routeTeal.opacity(0.7),
                                TrazoColors.routeTeal,
                            ],
                            center: .center
                        )
                    )
                    .frame(width: 200, height: 200)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(0.25), lineWidth: 4)
                    }
                    .rotationEffect(.degrees(rotation))
                    .animation(isSpinning ? .easeOut(duration: 2.4) : .default, value: rotation)

                Text("🎲")
                    .font(.system(size: 44))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, TrazoSpacing.sm)
    }

    private func spin() {
        guard candidates.count >= 2, !isSpinning else { return }
        isSpinning = true

        let spins = Double.random(in: 4...6) * 360
        rotation += spins

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            winner = CommunityRouteService.runRoulette(club: club, in: modelContext)
            isSpinning = false
        }
    }
}
