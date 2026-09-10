//
//  HealthKitService.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Integrazione HealthKit (ADR-0004 amendata da ADR-0027): il gym legge solo
//  il peso corporeo. Nessuna scrittura di workout — il modulo non crea più
//  sessioni.
//

import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }

    private var readTypes: Set<HKObjectType> { [bodyMass] }

    /// Richiede i permessi granulari. `true` se la richiesta è andata a buon
    /// fine (non implica che l'utente abbia concesso tutto).
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
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
