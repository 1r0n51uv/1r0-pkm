//
//  WatchSessionModel.swift
//  1r0-pkm-w Watch App
//
//  Stato di sessione in-memory sul Watch (ADR-0016: log autonomo). Ogni
//  mutazione parte verso l'iPhone via WatchConnector; l'iPhone la applica
//  a SwiftData e all'outbox verso il backend.
//

import Foundation
import WatchKit

@MainActor
final class WatchSessionModel: ObservableObject {
    @Published private(set) var sessionId: UUID?
    @Published private(set) var startedAt: Date?
    @Published private(set) var isPaused = false
    @Published private(set) var loggedSets: [(weightKg: Double, reps: Int)] = []

    /// Sessione HealthKit reale (FC + calorie attive dai sensori, ADR-0016).
    let workout = WatchWorkoutSession()

    var isActive: Bool { sessionId != nil }

    /// Da chiamare all'avvio: chiede i permessi HealthKit una volta.
    func primeHealthKit() { Task { await workout.requestAuthorization() } }

    func start() {
        let id = UUID()
        sessionId = id
        startedAt = .now
        isPaused = false
        loggedSets = []
        workout.start()
        WatchConnector.shared.enqueue([
            "type": "session.start", "id": id.uuidString,
            "startedAt": ISO8601DateFormatter().string(from: startedAt!),
        ])
        WKInterfaceDevice.current().play(.start)
    }

    func logSet(weightKg: Double, reps: Int) {
        guard let sid = sessionId, !isPaused else { return }
        loggedSets.append((weightKg, reps))
        WatchConnector.shared.enqueue([
            "type": "setlog.create", "id": UUID().uuidString,
            "sessionId": sid.uuidString, "exerciseName": "Serie libera",
            "setIndex": loggedSets.count, "weightKg": weightKg, "reps": reps,
        ])
        WKInterfaceDevice.current().play(.success)
    }

    func pause() {
        guard let sid = sessionId, !isPaused else { return }
        isPaused = true
        workout.pause()
        WatchConnector.shared.enqueue(["type": "session.pause", "id": sid.uuidString])
    }
    func resume() {
        guard let sid = sessionId, isPaused else { return }
        isPaused = false
        workout.resume()
        WatchConnector.shared.enqueue(["type": "session.resume", "id": sid.uuidString])
    }

    func end(cancelled: Bool) {
        guard let sid = sessionId else { return }
        // se HealthKit stava registrando, il Watch salva lui l'`HKWorkout`
        // con FC/calorie reali → l'iPhone non deve rifarne uno (ADR-0016).
        let hkSaved = !cancelled && workout.isRunning
        workout.end(discard: cancelled)
        WatchConnector.shared.enqueue([
            "type": "session.end", "id": sid.uuidString,
            "status": cancelled ? "cancelled" : "completed",
            "hkSaved": hkSaved,
        ])
        WKInterfaceDevice.current().play(cancelled ? .failure : .stop)
        sessionId = nil
        startedAt = nil
        isPaused = false
        loggedSets = []
    }
}
