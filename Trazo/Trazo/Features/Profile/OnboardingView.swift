import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthService.self) private var auth
    @Query private var profiles: [UserProfile]

    @State private var step = 0
    @State private var weightKg = 70.0
    @State private var fitnessLevel: FitnessLevel = .beginner
    @State private var averagePace = 6.5
    @State private var preferFlatRoutes = true
    @State private var avoidHighways = true

    @State private var importandoHealth = false
    @State private var healthLinked = false
    @State private var healthError: String?

    private let totalSteps = 3

    private var profile: UserProfile? {
        guard let uid = auth.userId else { return nil }
        return profiles.first { $0.id == uid }
    }

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
            .onAppear(perform: cargarDesdePerfil)
        }
    }

    // MARK: - Indicador de progreso

    private var progressIndicator: some View {
        HStack(spacing: TrazoSpacing.sm) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? TrazoColors.routeTeal : TrazoColors.surface)
                    .frame(height: 4)
            }
        }
    }

    // MARK: - Paso 1: Bienvenida

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
            Spacer()

            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(TrazoColors.routeTeal)

            Text("¡Hola, \(auth.nombreRegistro)!")
                .font(TrazoTypography.largeTitle())
                .foregroundStyle(TrazoColors.textPrimary)

            Text("Cuéntanos un poco sobre ti para personalizar tus Trazos con IA.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, TrazoSpacing.xl)
    }

    // MARK: - Paso 2: Condición física

    private var fitnessStep: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
            Spacer()

            Text("Tu condición física")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)

            healthCard

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

    private var healthCard: some View {
        TrazoCard {
            VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                HStack(spacing: TrazoSpacing.md) {
                    Image(systemName: healthLinked ? "heart.fill" : "heart.text.square.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(TrazoColors.accentOrange)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(healthLinked ? "Vinculado con Salud" : "¿Vincular con Salud?")
                            .font(TrazoTypography.headline())
                            .foregroundStyle(TrazoColors.textPrimary)
                        Text(healthLinked
                             ? "Tus datos se usan para personalizar Trazos con IA."
                             : "Importa peso, ritmo y VO₂ máx automáticamente.")
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.textSecondary)
                    }
                    Spacer()
                }

                if let healthError {
                    Text(healthError)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.accentOrange)
                }

                if !healthLinked {
                    TrazoButton(
                        title: importandoHealth ? "Importando…" : "Vincular con Salud",
                        style: .secondary,
                        isEnabled: !importandoHealth,
                        action: vincularHealth
                    )
                }
            }
        }
    }

    // MARK: - Paso 3: Preferencias

    private var preferencesStep: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
            Spacer()

            Text("Preferencias de Trazo")
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
                Toggle("Preferir Trazos planos", isOn: $preferFlatRoutes)
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

    // MARK: - Barra inferior

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

    private var canAdvance: Bool { true }

    private var formattedPace: String {
        let minutes = Int(averagePace)
        let seconds = Int((averagePace - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    // MARK: - Lógica

    private func cargarDesdePerfil() {
        guard let profile else { return }
        weightKg = profile.weightKg
        fitnessLevel = profile.fitnessLevel
        averagePace = profile.averagePaceMinPerKm
        preferFlatRoutes = profile.preferFlatRoutes
        avoidHighways = profile.avoidHighways
        healthLinked = profile.healthLinked
    }

    private func vincularHealth() {
        healthError = nil
        importandoHealth = true
        Task {
            do {
                try await HealthKitService.shared.requestPermissions()
                let snap = await HealthKitService.shared.loadSnapshot()
                if let v = snap.pesoKg { weightKg = v }
                if let v = snap.vo2Max { fitnessLevel = UserProfile.nivelDesdeVO2Max(v) }
                if let v = snap.ritmoPromedioMinPerKm { averagePace = v }
                profile?.applyHealthSnapshot(snap)
                healthLinked = true
            } catch {
                healthError = "No se pudo acceder a Salud. Puedes continuar manualmente."
            }
            importandoHealth = false
        }
    }

    private func completeOnboarding() {
        guard let uid = auth.userId, let correo = auth.email else { return }

        let perfil: UserProfile
        if let existente = profile {
            perfil = existente
        } else {
            perfil = UserProfile(id: uid, email: correo, remoto: nil)
            modelContext.insert(perfil)
        }

        perfil.displayName = auth.nombreRegistro.trimmingCharacters(in: .whitespaces)
        perfil.weightKg = weightKg
        perfil.fitnessLevel = fitnessLevel
        perfil.averagePaceMinPerKm = averagePace
        perfil.preferFlatRoutes = preferFlatRoutes
        perfil.avoidHighways = avoidHighways
        perfil.healthLinked = healthLinked
        perfil.hasCompletedOnboarding = true

        // Marcar aquí hace que RootView cambie a MainTabView
        auth.marcarOnboardingCompleto()

        Task {
            try? await UserProfileRepository.upsert(perfil)
        }
    }
}

#Preview {
    OnboardingView()
        .environment(AuthService())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
