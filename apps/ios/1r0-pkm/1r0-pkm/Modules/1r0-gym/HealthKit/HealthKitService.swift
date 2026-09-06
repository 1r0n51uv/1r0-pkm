//
//  HealthKitService.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Integrazione HealthKit (ADR-0004): scrive gli allenamenti completati in
//  Apple Salute, legge il peso corporeo. Watch `HKWorkoutSession` e
//  passi/calorie: rimandati.
//

import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }
    private var activeEnergy: HKQuantityType { HKQuantityType(.activeEnergyBurned) }

    private var readTypes: Set<HKObjectType> {
        [bodyMass, HKQuantityType(.stepCount), activeEnergy]
    }
    private var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), activeEnergy]
    }

    /// Richiede i permessi granulari. `true` se la richiesta è andata a buon
    /// fine (non implica che l'utente abbia concesso tutto).
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// Salva una sessione completata come `HKWorkout` (Functional Strength
    /// Training). Le sessioni `cancelled` non vanno in Salute (ADR-0016).
    func saveCompletedWorkout(start: Date, end: Date, activeEnergyKcal: Double?) async {
        guard isAvailable, end > start else { return }
        guard store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .functionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            if let kcal = activeEnergyKcal, kcal > 0 {
                let sample = HKQuantitySample(
                    type: activeEnergy,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                    start: start, end: end)
                try await builder.addSamples([sample])
            }
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
        } catch {
            // best-effort: se fallisce non blocca il flusso di fine sessione
        }
    }

    /// Peso corporeo più recente da Salute, in kg. `nil` se non disponibile
    /// o non autorizzato.
    func latestBodyWeightKg() async -> Double? {
        guard isAvailable,
              store.authorizationStatus(for: bodyMass) != .notDetermined else { return nil }
        return await withCheckedContinuation { cont in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            let q = HKSampleQuery(sampleType: bodyMass, predicate: nil, limit: 1, sortDescriptors: sort) { _, samples, _ in
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                cont.resume(returning: kg)
            }
            store.execute(q)
        }
    }
}
