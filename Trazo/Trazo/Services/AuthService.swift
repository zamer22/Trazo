import Foundation
import Supabase

enum AuthError: LocalizedError {
    case credencialesInvalidas
    case correoYaRegistrado
    case correoInvalido
    case contrasenaDebil
    case sinConexion
    case desconocido

    var errorDescription: String? {
        switch self {
        case .credencialesInvalidas: "Correo o contraseña incorrectos."
        case .correoYaRegistrado: "Este correo ya está registrado."
        case .correoInvalido: "El correo no es válido."
        case .contrasenaDebil: "La contraseña debe tener al menos 6 caracteres."
        case .sinConexion: "Sin conexión. Revisa tu internet e intenta de nuevo."
        case .desconocido: "No se pudo completar la operación. Inténtalo de nuevo."
        }
    }
}

@MainActor
@Observable
final class AuthService {
    private(set) var session: Session?
    private(set) var isLoading = false

    private let client = SupabaseService.client
    private var listenerTask: Task<Void, Never>?

    var isSignedIn: Bool { session != nil }
    var userId: UUID? { session?.user.id }
    var email: String? { session?.user.email }
    private(set) var registroReciente = false
    private(set) var nombreRegistro = ""

    init() {
        listenerTask = Task { [weak self] in
            guard let self else { return }
            for await (_, sesion) in client.auth.authStateChanges {
                self.session = sesion
                // Al cerrar sesión, limpiar el flag para que el próximo login vaya directo al mapa
                if sesion == nil { self.registroReciente = false }
            }
        }
    }

    func marcarOnboardingCompleto() {
        registroReciente = false
    }

    func signUp(correo: String, contrasena: String, nombreUsuario: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let respuesta = try await client.auth.signUp(
                email: correo,
                password: contrasena,
                data: ["nombre_usuario": .string(nombreUsuario)]
            )
            self.session = respuesta.session
            self.registroReciente = true
            self.nombreRegistro = nombreUsuario
        } catch {
            throw mapError(error)
        }
    }

    func signIn(correo: String, contrasena: String) async throws {
        isLoading = true
        defer { isLoading = false }
        do {
            let sesion = try await client.auth.signIn(email: correo, password: contrasena)
            self.session = sesion
        } catch {
            throw mapError(error)
        }
    }

    func signOut() async throws {
        try await client.auth.signOut()
        self.session = nil
    }

    private func mapError(_ error: Error) -> Error {
        let msg = error.localizedDescription.lowercased()
        if msg.contains("network") || msg.contains("offline") || msg.contains("internet") {
            return AuthError.sinConexion
        }
        if msg.contains("invalid login") || (msg.contains("invalid") && msg.contains("credentials")) {
            return AuthError.credencialesInvalidas
        }
        if msg.contains("already registered") || msg.contains("already exists") || msg.contains("user already") {
            return AuthError.correoYaRegistrado
        }
        if msg.contains("invalid email") || msg.contains("email address") {
            return AuthError.correoInvalido
        }
        if msg.contains("weak password") || (msg.contains("password") && msg.contains("6")) {
            return AuthError.contrasenaDebil
        }
        return AuthError.desconocido
    }
}
