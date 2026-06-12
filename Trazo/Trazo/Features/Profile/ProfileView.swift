import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.currentUserProfile) private var profile
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @AppStorage("appColorScheme") private var appColorScheme = AppColorScheme.light.rawValue
    @State private var isSettingsPresented = false

    private var currentScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorScheme) ?? .light
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: TrazoSpacing.lg) {
                    if let profile {
                        header(for: profile)
                        statsSection(for: profile)
                        preferencesSection(for: profile)
                    } else {
                        FeaturePlaceholderView(
                            icon: "person.circle",
                            title: "Sin perfil",
                            subtitle: "Completa el onboarding para ver tu perfil."
                        )
                        .frame(height: 300)
                    }
                }
                .padding(TrazoSpacing.lg)
            }
            .background(TrazoColors.background)
            .navigationTitle("Perfil")
            .toolbar {
                if profile != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                                .foregroundStyle(TrazoColors.textPrimary)
                        }
                        .accessibilityLabel("Ajustes")
                    }
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                if let profile {
                    ProfileSettingsView(profile: profile)
                }
            }
        }
    }

    @ViewBuilder
    private func header(for profile: UserProfile) -> some View {
        TrazoCard {
            HStack(spacing: TrazoSpacing.lg) {
                TrazoAvatar(
                    initials: profile.displayName.prefix(2).uppercased(),
                    color: TrazoColors.accentOrange,
                    size: 64
                )

                VStack(alignment: .leading, spacing: TrazoSpacing.xs) {
                    Text(profile.displayName)
                        .font(TrazoTypography.title())
                        .foregroundStyle(TrazoColors.textPrimary)

                    Text(profile.fitnessLevel.rawValue)
                        .font(TrazoTypography.caption())
                        .foregroundStyle(TrazoColors.textSecondary)
                }

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func statsSection(for profile: UserProfile) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: TrazoSpacing.md
        ) {
            TrazoStatCard(label: "Peso", value: "\(Int(profile.weightKg)) kg")
            TrazoStatCard(label: "Ritmo", value: profile.formattedPace)
        }
    }

    @ViewBuilder
    private func preferencesSection(for profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.md) {
            Text("Preferencias")
                .font(TrazoTypography.headline())
                .foregroundStyle(TrazoColors.textPrimary)

            TrazoCard {
                VStack(alignment: .leading, spacing: TrazoSpacing.md) {
                    appearanceToggleRow

                    preferenceRow(
                        title: "Rutas planas",
                        enabled: profile.preferFlatRoutes
                    )
                    preferenceRow(
                        title: "Evitar autopistas",
                        enabled: profile.avoidHighways
                    )
                }
            }

            TrazoButton(title: "Cerrar sesión", style: .secondary) {
                resetProfile()
            }
        }
    }

    private var appearanceToggleRow: some View {
        Button {
            appColorScheme = currentScheme.toggled.rawValue
        } label: {
            HStack {
                Image(systemName: currentScheme.toggleIcon)
                    .foregroundStyle(TrazoColors.routeTeal)
                Text(currentScheme.toggleLabel)
                    .font(TrazoTypography.body())
                    .foregroundStyle(TrazoColors.textPrimary)
                Spacer()
            }
        }
    }

    private func preferenceRow(title: String, enabled: Bool) -> some View {
        HStack {
            Text(title)
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textPrimary)
            Spacer()
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(enabled ? TrazoColors.routeTeal : TrazoColors.textSecondary)
        }
    }

    private func resetProfile() {
        profiles.forEach { modelContext.delete($0) }
    }
}

struct ProfileSettingsView: View {
    @Bindable var profile: UserProfile
    @AppStorage("appColorScheme") private var appColorScheme = AppColorScheme.light.rawValue
    @Environment(\.dismiss) private var dismiss

    private var currentScheme: AppColorScheme {
        AppColorScheme(rawValue: appColorScheme) ?? .light
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Apariencia") {
                    Button {
                        appColorScheme = currentScheme.toggled.rawValue
                    } label: {
                        Label(currentScheme.toggleLabel, systemImage: currentScheme.toggleIcon)
                    }
                }

                Section("Datos") {
                    TextField("Nombre", text: $profile.displayName)
                    Picker("Nivel", selection: Binding(
                        get: { profile.fitnessLevel },
                        set: { profile.fitnessLevel = $0 }
                    )) {
                        ForEach(FitnessLevel.allCases) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }
                }

                Section("Físico") {
                    Stepper("Peso: \(Int(profile.weightKg)) kg", value: $profile.weightKg, in: 40...120)
                    Slider(
                        value: $profile.averagePaceMinPerKm,
                        in: 4...10,
                        step: 0.25
                    ) {
                        Text("Ritmo: \(profile.formattedPace)")
                    }
                }

                Section("Rutas") {
                    Toggle("Rutas planas", isOn: $profile.preferFlatRoutes)
                    Toggle("Evitar autopistas", isOn: $profile.avoidHighways)
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(previewContainer)
}

@MainActor
private var previewContainer: ModelContainer {
    let container = try! ModelContainer(for: UserProfile.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let profile = UserProfile(displayName: "Diego", hasCompletedOnboarding: true)
    container.mainContext.insert(profile)
    return container
}
