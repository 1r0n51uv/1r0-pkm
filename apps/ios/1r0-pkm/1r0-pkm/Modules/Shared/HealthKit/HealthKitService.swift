//
//  HealthKitService.swift
//  1r0-pkm · Modules/Shared/HealthKit
//
//  Gateway HealthKit condiviso (ADR-0004 amendata da ADR-0027).
//  - `gym` legge il peso corporeo (andamento nei Progressi).
//  - `diet` **scrive** energia + macro per ogni pasto loggato e **legge**
//    acqua ed energia attiva (quota giornaliera + promemoria acqua).
//  L'app resta la fonte di verità; Salute è uno specchio in uscita (+ input
//  per peso/acqua/energia). Scrittura one-way, best-effort.
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
    private var dietaryWater: HKQuantityType { HKQuantityType(.dietaryWater) }
    private var dietaryEnergy: HKQuantityType { HKQuantityType(.dietaryEnergyConsumed) }
    private var dietaryProtein: HKQuantityType { HKQuantityType(.dietaryProtein) }
    private var dietaryCarbs: HKQuantityType { HKQuantityType(.dietaryCarbohydrates) }
    private var dietaryFat: HKQuantityType { HKQuantityType(.dietaryFatTotal) }

    private var readTypes: Set<HKObjectType> { [bodyMass, activeEnergy, dietaryWater] }
    private var writeTypes: Set<HKSampleType> {
        [dietaryEnergy, dietaryProtein, dietaryCarbs, dietaryFat]
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

    // MARK: - lettura

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

    /// Energia attiva bruciata oggi (kcal). `0` se non disponibile/autorizzato.
    func todayActiveEnergyKcal() async -> Double {
        await sumToday(activeEnergy, unit: .kilocalorie())
    }

    /// Acqua registrata oggi in Salute (ml). `0` se non disponibile/autorizzato.
    func todayDietaryWaterMl() async -> Double {
        await sumToday(dietaryWater, unit: .literUnit(with: .milli))
    }

    private func sumToday(_ type: HKQuantityType, unit: HKUnit) async -> Double {
        guard isAvailable,
              store.authorizationStatus(for: type) != .notDetermined else { return 0 }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: pred,
                                      options: .cumulativeSum) { _, stats, _ in
                cont.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    // MARK: - scrittura (diet → Salute)

    /// Scrive un pasto come samples dietetici (energia + macro). Best-effort,
    /// one-way: se un tipo non è autorizzato o il valore è 0 lo salta.
    func saveMeal(energyKcal: Double, proteinG: Double, carbsG: Double, fatG: Double,
                  at date: Date) async {
        guard isAvailable else { return }
        var samples: [HKQuantitySample] = []
        func add(_ type: HKQuantityType, _ unit: HKUnit, _ value: Double) {
            guard value > 0,
                  store.authorizationStatus(for: type) == .sharingAuthorized else { return }
            samples.append(HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: date, end: date))
        }
        add(dietaryEnergy, .kilocalorie(), energyKcal)
        add(dietaryProtein, .gram(), proteinG)
        add(dietaryCarbs, .gram(), carbsG)
        add(dietaryFat, .gram(), fatG)
        guard !samples.isEmpty else { return }
        try? await store.save(samples)
    }
}
