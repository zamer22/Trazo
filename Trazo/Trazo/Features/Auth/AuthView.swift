import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth

    private enum Modo: String, CaseIterable, Identifiable {
        case ingresar = "Ingresar"
        case registrarse = "Registrarse"
        var id: String { rawValue }
    }

    @State private var modo: Modo = .ingresar
    @State private var nombreUsuario = ""
    @State private var correo = ""
    @State private var contrasena = ""
    @State private var error: String?

    var body: some View {
        ZStack {
            TrazoColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                hero
                    .padding(.top, TrazoSpacing.xxxl)

                Spacer(minLength: TrazoSpacing.xl)

                ScrollView {
                    VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                        modoPicker
                        formulario
                        if let error {
                            Text(error)
                                .font(TrazoTypography.caption())
                                .foregroundStyle(TrazoColors.accentOrange)
                        }
                        TrazoButton(
                            title: modo == .ingresar ? "Ingresar" : "Crear cuenta",
                            isEnabled: puedeEnviar && !auth.isLoading,
                            action: enviar
                        )
                        cambiarModo
                    }
                    .padding(TrazoSpacing.xl)
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: TrazoSpacing.md) {
            Image(systemName: "figure.run.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(TrazoColors.routeTeal)

            Text("Trazo")
                .font(TrazoTypography.largeTitle())
                .foregroundStyle(TrazoColors.textPrimary)

            Text("Tus rutas, tu ritmo, tu comunidad.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
        }
    }

    private var modoPicker: some View {
        Picker("", selection: $modo) {
            ForEach(Modo.allCases) { opcion in
                Text(opcion.rawValue).tag(opcion)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: modo) { _, _ in error = nil }
    }

    private var formulario: some View {
        VStack(spacing: TrazoSpacing.md) {
            if modo == .registrarse {
                campo(titulo: "Nombre", placeholder: "Ej. Diego", texto: $nombreUsuario)
            }
            campo(
                titulo: "Correo",
                placeholder: "tu@correo.com",
                texto: $correo,
                keyboard: .emailAddress,
                content: .emailAddress
            )
            campo(
                titulo: "Contraseña",
                placeholder: "Mínimo 6 caracteres",
                texto: $contrasena,
                seguro: true,
                content: modo == .ingresar ? .password : .newPassword
            )
        }
    }

    private func campo(
        titulo: String,
        placeholder: String,
        texto: Binding<String>,
        seguro: Bool = false,
        keyboard: UIKeyboardType = .default,
        content: UITextContentType? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text(titulo)
                .font(TrazoTypography.caption())
                .foregroundStyle(TrazoColors.textSecondary)

            Group {
                if seguro {
                    SecureField(placeholder, text: texto)
                } else {
                    TextField(placeholder, text: texto)
                }
            }
            .font(TrazoTypography.body())
            .textInputAutocapitalization(seguro ? .never : (keyboard == .emailAddress ? .never : .words))
            .autocorrectionDisabled()
            .keyboardType(keyboard)
            .textContentType(content)
            .padding(TrazoSpacing.lg)
            .background(TrazoColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: TrazoRadius.md, style: .continuous))
        }
    }

    private var cambiarModo: some View {
        HStack {
            Spacer()
            Button {
                modo = modo == .ingresar ? .registrarse : .ingresar
                error = nil
            } label: {
                Text(modo == .ingresar
                     ? "¿Aún no tienes cuenta? Regístrate"
                     : "¿Ya tienes cuenta? Ingresa")
                    .font(TrazoTypography.caption())
                    .foregroundStyle(TrazoColors.routeTeal)
            }
            Spacer()
        }
    }

    private var puedeEnviar: Bool {
        let correoOk = correo.contains("@") && correo.contains(".")
        let contrasenaOk = contrasena.count >= 6
        let nombreOk = modo == .ingresar || !nombreUsuario.trimmingCharacters(in: .whitespaces).isEmpty
        return correoOk && contrasenaOk && nombreOk
    }

    private func enviar() {
        error = nil
        Task {
            do {
                if modo == .ingresar {
                    try await auth.signIn(
                        correo: correo.trimmingCharacters(in: .whitespacesAndNewlines),
                        contrasena: contrasena
                    )
                } else {
                    try await auth.signUp(
                        correo: correo.trimmingCharacters(in: .whitespacesAndNewlines),
                        contrasena: contrasena,
                        nombreUsuario: nombreUsuario.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthView()
        .environment(AuthService())
}
