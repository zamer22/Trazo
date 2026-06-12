import Foundation
import SwiftData

enum FitnessLevel: String, CaseIterable, Codable, Identifiable {
    case beginner = "Principiante"
    case intermediate = "Intermedio"
    case advanced = "Avanzado"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .beginner: "Empiezas o corres ocasionalmente"
        case .intermediate: "Corres con regularidad"
        case .advanced: "Entrenas con frecuencia y ritmo alto"
        }
    }
}

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var email: String
    var displayName: String
    var weightKg: Double
    var heightCm: Double?
    var age: Int?
    var sex: String?
    var restingHR: Int?
    var vo2Max: Double?
    var fitnessLevelRaw: String
    var averagePaceMinPerKm: Double
    var weeklyRuns: Int?
    var preferFlatRoutes: Bool
    var avoidHighways: Bool
    var healthLinked: Bool
    var hasCompletedOnboarding: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        email: String = "",
        displayName: String = "",
        weightKg: Double = 70,
        heightCm: Double? = nil,
        age: Int? = nil,
        sex: String? = nil,
        restingHR: Int? = nil,
        vo2Max: Double? = nil,
        fitnessLevel: FitnessLevel = .beginner,
        averagePaceMinPerKm: Double = 6.5,
        weeklyRuns: Int? = nil,
        preferFlatRoutes: Bool = true,
        avoidHighways: Bool = true,
        healthLinked: Bool = false,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.age = age
        self.sex = sex
        self.restingHR = restingHR
        self.vo2Max = vo2Max
        self.fitnessLevelRaw = fitnessLevel.rawValue
        self.averagePaceMinPerKm = averagePaceMinPerKm
        self.weeklyRuns = weeklyRuns
        self.preferFlatRoutes = preferFlatRoutes
        self.avoidHighways = avoidHighways
        self.healthLinked = healthLinked
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.createdAt = createdAt
    }

    var fitnessLevel: FitnessLevel {
        get { FitnessLevel(rawValue: fitnessLevelRaw) ?? .beginner }
        set { fitnessLevelRaw = newValue.rawValue }
    }

    var formattedPace: String {
        let minutes = Int(averagePaceMinPerKm)
        let seconds = Int((averagePaceMinPerKm - Double(minutes)) * 60)
        return String(format: "%d:%02d /km", minutes, seconds)
    }

    func applyHealthSnapshot(_ snap: HealthSnapshot) {
        if let v = snap.pesoKg { weightKg = v }
        if let v = snap.alturaCm { heightCm = v }
        if let v = snap.edad { age = v }
        if let v = snap.sexo { sex = v }
        if let v = snap.fcReposo { restingHR = v }
        if let v = snap.vo2Max {
            vo2Max = v
            fitnessLevel = Self.nivelDesdeVO2Max(v)
        }
        if let v = snap.ritmoPromedioMinPerKm { averagePaceMinPerKm = v }
        if let v = snap.corridasSemanales { weeklyRuns = v }
        healthLinked = true
    }

    static func nivelDesdeVO2Max(_ vo2: Double) -> FitnessLevel {
        switch vo2 {
        case ..<35: .beginner
        case 35..<50: .intermediate
        default: .advanced
        }
    }

    convenience init(id: UUID, email: String, remoto: RemoteUserProfile?) {
        let nivel = FitnessLevel(rawValue: remoto?.nivel ?? "") ?? .beginner
        self.init(
            id: id,
            email: remoto?.correo ?? email,
            displayName: remoto?.nombreUsuario ?? "",
            weightKg: remoto?.pesoKg ?? 70,
            heightCm: remoto?.alturaCm,
            age: remoto?.edad,
            sex: remoto?.sexo,
            restingHR: remoto?.fcReposo,
            vo2Max: remoto?.vo2Max,
            fitnessLevel: nivel,
            averagePaceMinPerKm: remoto?.ritmoPromedioMinPerKm ?? 6.5,
            weeklyRuns: remoto?.corridasSemanales,
            preferFlatRoutes: remoto?.prefiereRutasPlanas ?? true,
            avoidHighways: remoto?.evitaAutopistas ?? true,
            healthLinked: remoto?.healthVinculado ?? false,
            hasCompletedOnboarding: remoto?.onboardingCompletado ?? false
        )
    }
}
