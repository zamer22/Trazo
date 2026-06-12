import Foundation

@MainActor
@Observable
final class ActiveRunManager {
    static let shared = ActiveRunManager()
    var hayCorridaActiva = false
    private init() {}
}
