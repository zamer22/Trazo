import Foundation
import HealthKit

struct HealthSnapshot: Sendable {
    var pesoKg: Double?
    var alturaCm: Double?
    var edad: Int?
    var sexo: String?
    var fcReposo: Int?
    var vo2Max: Double?
    var ritmoPromedioMinPerKm: Double?
    var corridasSemanales: Int?
}

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var tipos: Set<HKObjectType> = [
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.vo2Max),
            HKWorkoutType.workoutType()
        ]
        tipos.insert(HKCharacteristicType(.dateOfBirth))
        tipos.insert(HKCharacteristicType(.biologicalSex))
        return tipos
    }

    func requestPermissions() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func loadSnapshot() async -> HealthSnapshot {
        var snap = HealthSnapshot()
        snap.pesoKg = await latestQuantity(.bodyMass, unit: .gramUnit(with: .kilo))
        snap.alturaCm = await latestQuantity(.height, unit: .meterUnit(with: .centi))
        snap.fcReposo = await latestQuantity(
            .restingHeartRate,
            unit: HKUnit.count().unitDivided(by: .minute())
        ).map { Int($0.rounded()) }
        snap.vo2Max = await latestQuantity(.vo2Max, unit: HKUnit(from: "ml/kg*min"))
        snap.edad = edadDesdeFechaNacimiento()
        snap.sexo = sexoBiologico()
        let resumen = await resumenCarreras(dias: 30)
        snap.ritmoPromedioMinPerKm = resumen.ritmo
        snap.corridasSemanales = resumen.porSemana
        return snap
    }

    // MARK: - Lecturas individuales

    private func latestQuantity(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let tipo = HKQuantityType(id)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: tipo)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        let muestras = try? await descriptor.result(for: store)
        return muestras?.first?.quantity.doubleValue(for: unit)
    }

    private func edadDesdeFechaNacimiento() -> Int? {
        guard let comps = try? store.dateOfBirthComponents(),
              let nacimiento = Calendar.current.date(from: comps) else { return nil }
        return Calendar.current.dateComponents([.year], from: nacimiento, to: Date()).year
    }

    private func sexoBiologico() -> String? {
        guard let sex = try? store.biologicalSex().biologicalSex else { return nil }
        switch sex {
        case .female: return "Femenino"
        case .male: return "Masculino"
        case .other: return "Otro"
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    private struct ResumenCarreras {
        var ritmo: Double?
        var porSemana: Int?
    }

    private func resumenCarreras(dias: Int) async -> ResumenCarreras {
        let predicado = HKQuery.predicateForWorkouts(with: .running)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.workout(predicado)],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)]
        )
        guard let workouts = try? await descriptor.result(for: store), !workouts.isEmpty else {
            return ResumenCarreras()
        }

        let desde = Calendar.current.date(byAdding: .day, value: -dias, to: Date()) ?? Date()
        let recientes = workouts.filter { $0.endDate >= desde }
        guard !recientes.isEmpty else { return ResumenCarreras() }

        let segundos = recientes.reduce(0.0) { $0 + $1.duration }
        let metros = recientes.reduce(0.0) { acc, workout in
            let suma = workout.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()
            return acc + (suma?.doubleValue(for: .meter()) ?? 0)
        }
        let ritmo: Double? = metros > 0 ? (segundos / 60.0) / (metros / 1000.0) : nil
        let semanas = max(1.0, Double(dias) / 7.0)
        let porSemana = Int((Double(recientes.count) / semanas).rounded())
        return ResumenCarreras(ritmo: ritmo, porSemana: porSemana)
    }
}
