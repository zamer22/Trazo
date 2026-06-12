import SwiftUI

struct AuthView: View {
    @Environment(AuthService.self) private var auth

    @State private var modoRegistro = false
    @State private var nombreUsuario = ""
    @State private var correo = ""
    @State private var contrasena = ""
    @State private var errorMensaje: String?

    var body: some View {
        ZStack {
            TrazoColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                hero

                Spacer(minLength: TrazoSpacing.xxxl)

                VStack(alignment: .leading, spacing: TrazoSpacing.xl) {
                    encabezado

                    formulario

                    if let errorMensaje {
                        Text(errorMensaje)
                            .font(TrazoTypography.caption())
                            .foregroundStyle(TrazoColors.accentOrange)
                            .transition(.opacity)
                    }

                    TrazoButton(
                        title: modoRegistro ? "Crear cuenta" : "Ingresar",
                        isEnabled: puedeEnviar && !auth.isLoading,
                        action: enviar
                    )
                }
                .padding(.horizontal, TrazoSpacing.xl)
                .animation(.easeInOut(duration: 0.25), value: modoRegistro)

                Spacer()

                cambiarModo
                    .padding(.bottom, TrazoSpacing.xxxl)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: TrazoSpacing.lg) {
            Image("TrazoLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .accessibilityLabel("Trazo")

            Text("Trazo")
            .font(TrazoTypography.largeTitle())
            .foregroundStyle(TrazoColors.textPrimary)
            Text("Tus Trazos, tu ritmo, tu comunidad.")
                .font(TrazoTypography.body())
                .foregroundStyle(TrazoColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var encabezado: some View {
        VStack(alignment: .leading, spacing: TrazoSpacing.sm) {
            Text(modoRegistro ? "Crea tu cuenta" : "Bienvenido de vuelta")
                .font(TrazoTypography.title())
                .foregroundStyle(TrazoColors.textPrimary)
        }
    }

    private var formulario: some View {
        VStack(spacing: TrazoSpacing.md) {
            if modoRegistro {
                campo(
                    titulo: "Nombre",
                    placeholder: "Ej. Diego",
                    texto: $nombreUsuario,
                    content: .name
                )
                .transition(.move(edge: .top).combined(with: .opacity))
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
                content: modoRegistro ? .newPassword : .password
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
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                modoRegistro.toggle()
                errorMensaje = nil
                nombreUsuario = ""
            }
        } label: {
            Group {
                if modoRegistro {
                    Text("¿Ya tienes cuenta? ") + Text("Inicia sesión").bold()
                } else {
                    Text("¿Aún no tienes cuenta? ") + Text("Regístrate").bold()
                }
            }
            .font(TrazoTypography.caption())
            .foregroundStyle(TrazoColors.textSecondary)
        }
    }

    private var puedeEnviar: Bool {
        let correoOk = correo.contains("@") && correo.contains(".")
        let contrasenaOk = contrasena.count >= 6
        let nombreOk = !modoRegistro || !nombreUsuario.trimmingCharacters(in: .whitespaces).isEmpty
        return correoOk && contrasenaOk && nombreOk
    }

    private func enviar() {
        errorMensaje = nil
        Task {
            do {
                if modoRegistro {
                    try await auth.signUp(
                        correo: correo.trimmingCharacters(in: .whitespacesAndNewlines),
                        contrasena: contrasena,
                        nombreUsuario: nombreUsuario.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                } else {
                    try await auth.signIn(
                        correo: correo.trimmingCharacters(in: .whitespacesAndNewlines),
                        contrasena: contrasena
                    )
                }
            } catch {
                errorMensaje = error.localizedDescription
            }
        }
    }
}

#Preview("Light") {
    AuthView()
        .environment(AuthService())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    AuthView()
        .environment(AuthService())
        .preferredColorScheme(.dark)
}
