import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var step = 0
    @State private var displayName = ""
    @State private var weightKg = 70.0
    @State private var fitnessLevel: FitnessLevel = .beginner
    @State private var averagePace = 6.5
    @State private var preferFlatRoutes = true
    @State private var avoidHighways = true

    private let totalSteps = 3

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressIndicator
                    .padding(.horizontal, TrazoSpacing.xl)
                    .padding(.top, TrazoSpacing.lg)

                TabView(selection: $step) {
                    welcomeStep.tag(0)
                    fitnessStep.tag(1)
                    preferencesStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: step)

                bottomBar
                    .padding(TrazoSpacing.xl)
            }
            .background(TrazoColors.background)
            .navigationBarHidden(true)
        }
    }

    private var progressIndicator: some View {
        HStack(spacing: TrazoSpacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? TrazoColors.routeTeal : TrazoColors.surface)
                    .frame(height: 4)
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(TrazoColors.routeTeal)

            Text("Bienvenido a Trazo")
                .font(TrazoTypography.largeTitle())
                .foregroundStyle(TrazoColors.textPrimary)

            Text("Cuéntanos un poco sobre ti para personalizar tus rutas de running.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)

            VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                Text("Tu nombre")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                TextField("Ej. Diego", text: $displayName)
                    .font(TrazoTypography.body())
                    .padding(TrazoSpacing.lg)
                    .background(TrazoColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
            }

            Spacer()
        }
        .padding(.horizontal, TrazoSpacing.xl)
    }

    private var fitnessStep: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
            Spacer()

            Text("Tu condición física")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)

            VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                Text("Peso (kg): \(Int(weightKg))")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                Slider(value: $weightKg, in: 40...120, step: 1)
                    .tint(TrazoColors.routeTeal)
            }

            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                Text("Nivel")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                ForEach(FitnessLevel.allCases) { level in
                    Button {
                        fitnessLevel = level
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.rawValue)
                                    .font(TrazoTypography.headline())
                                Text(level.description)
                                    .font(TrazoTypography.caption())
                            }
                            Spacer()
                            if fitnessLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(TrazoColors.routeTeal)
                            }
                        }
                        .foregroundStyle(TrazoColors.textPrimary)
                        .padding(TrazoSpacing.lg)
                        .background(fitnessLevel == level ? TrazoColors.elevated : TrazoColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, TrazoSpacing.xl)
    }

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
            Spacer()

            Text("Preferencias de ruta")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)

            VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
                Text("Ritmo promedio: \(formattedPace)")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.textSecondary)

                Slider(value: $averagePace, in: 4...10, step: 0.25)
                    .tint(TrazoColors.routeTeal)
            }

            TrazoCard {
                Toggle("Preferir rutas planas", isOn: $preferFlatRoutes)
                    .font(TrazoTypography.body())
                    .tint(TrazoColors.routeTeal)
            }

            TrazoCard {
                Toggle("Evitar autopistas", isOn: $avoidHighways)
                    .font(TrazoTypography.body())
                    .tint(TrazoColors.routeTeal)
            }

            Spacer()
        }
        .padding(.horizontal, TrazoSpacing.xl)
    }

    private var bottomBar: some View {
        HStack(spacing: TrazoSpacing.md) {
            if step > 0 {
                TrazoButton(title: "Atrás", style: .secondary) {
                    step -= 1
                }
            }

            TrazoButton(
                title: step == totalSteps - 1 ? "Empezar" : "Siguiente",
                isEnabled: canAdvance
            ) {
                if step == totalSteps - 1 {
                    completeOnboarding()
                } else {
                    step += 1
                }
            }
        }
    }

    private var canAdvance: Bool {
        step != 0 || !displayName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var formattedPace: String {
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    private func completeOnboarding() {
        let profile = UserProfile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            weightKg: weightKg,
            fitnessLevel: fitnessLevel,
            averagePaceMinPerKm: averagePace,
            preferFlatRoutes: preferFlatRoutes,
            avoidHighways: avoidHighways,
            hasCompletedOnboarding: true
        )
        modelContext.insert(profile)
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: UserProfile.self, inMemory: true)
}
