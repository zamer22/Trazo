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
    var displayName: String
    var weightKg: Double
    var fitnessLevelRaw: String
    var averagePaceMinPerKm: Double
    var preferFlatRoutes: Bool
    var avoidHighways: Bool
    var hasCompletedOnboarding: Bool
    var createdAt: Date

    init(
        displayName: String = "",
        weightKg: Double = 70,
        fitnessLevel: FitnessLevel = .beginner,
        averagePaceMinPerKm: Double = 6.5,
        preferFlatRoutes: Bool = true,
        avoidHighways: Bool = true,
        hasCompletedOnboarding: Bool = false,
        createdAt: Date = .now
    ) {
        self.displayName = displayName
        self.weightKg = weightKg
        self.fitnessLevelRaw = fitnessLevel.rawValue
        self.averagePaceMinPerKm = averagePaceMinPerKm
        self.preferFlatRoutes = preferFlatRoutes
        self.avoidHighways = avoidHighways
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
}
