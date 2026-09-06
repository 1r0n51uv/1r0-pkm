//
//  WatchWorkoutSession.swift
//  1r0-pkm-w Watch App
//
//  ADR-0016: durante un allenamento il Watch avvia un `HKWorkoutSession`
//  reale (strength training) con `HKLiveWorkoutBuilder`, così Apple Salute
//  registra frequenza cardiaca e calorie attive con i sensori del Watch e
//  la app mostra i valori live al polso. Una sessione *annullata* scarta il
//  workout (niente scrittura, coerente con ADR-0016/0004).
//
//  Difensivo: se HealthKit non è disponibile o l'utente nega i permessi,
//  ogni metodo è un no-op — il log serie continua a funzionare comunque.
//

import Foundation
import HealthKit

@MainActor
final class WatchWorkoutSession: NSObject, ObservableObject {
    @Published private(set) var heartRate: Double = 0        // bpm
    @Published private(set) var activeEnergyKcal: Double = 0
    @Published private(set) var isRunning = false

    private let store = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.stepCount), HKObjectType.workoutType()]
    }
    private var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.activeEnergyBurned), HKQuantityType(.heartRate),
         HKObjectType.workoutType()]
    }

    /// Chiede i permessi una volta (idempotente). Sicuro da chiamare all'avvio.
    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    /// Avvia la sessione HealthKit. Se qualcosa non va, resta tutto spento.
    func start() {
        guard HKHealthStore.isHealthDataAvailable(), session == nil else { return }
        let cfg = HKWorkoutConfiguration()
        cfg.activityType = .traditionalStrengthTraining
        cfg.locationType = .indoor
        do {
            let s = try HKWorkoutSession(healthStore: store, configuration: cfg)
            let b = s.associatedWorkoutBuilder()
            b.dataSource = HKLiveWorkoutDataSource(healthStore: store, workoutConfiguration: cfg)
            b.delegate = self
            s.delegate = self
            session = s
            builder = b
            let now = Date()
            s.startActivity(with: now)
            b.beginCollection(withStart: now) { [weak self] ok, _ in
                Task { @MainActor in self?.isRunning = ok }
            }
        } catch {
            session = nil
            builder = nil
        }
    }

    func pause() { session?.pause() }
    func resume() { session?.resume() }

    /// Chiude la sessione. `discard = true` (annullata) → nessuna scrittura
    /// in Salute; altrimenti salva l'`HKWorkout` con i campioni raccolti.
    func end(discard: Bool) {
        guard let s = session, let b = builder else { reset(); return }
        s.end()
        if discard {
            b.discardWorkout()
            reset()
        } else {
            b.endCollection(withEnd: Date()) { [weak self] _, _ in
                b.finishWorkout { _, _ in Task { @MainActor in self?.reset() } }
            }
        }
    }

    private func reset() {
        session = nil
        builder = nil
        isRunning = false
        heartRate = 0
        activeEnergyKcal = 0
    }
}

extension WatchWorkoutSession: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(_ ws: HKWorkoutSession,
                                    didChangeTo to: HKWorkoutSessionState,
                                    from: HKWorkoutSessionState, date: Date) { }
    nonisolated func workoutSession(_ ws: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in self.reset() }
    }
}

extension WatchWorkoutSession: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ b: HKLiveWorkoutBuilder) { }

    nonisolated func workoutBuilder(_ b: HKLiveWorkoutBuilder,
                                    didCollectDataOf types: Set<HKSampleType>) {
        for type in types {
            guard let qt = type as? HKQuantityType,
                  let stats = b.statistics(for: qt) else { continue }
            if qt == HKQuantityType(.heartRate) {
                let unit = HKUnit.count().unitDivided(by: .minute())
                let bpm = stats.mostRecentQuantity()?.doubleValue(for: unit) ?? 0
                Task { @MainActor in self.heartRate = bpm }
            } else if qt == HKQuantityType(.activeEnergyBurned) {
                let kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                Task { @MainActor in self.activeEnergyKcal = kcal }
            }
        }
    }
}
