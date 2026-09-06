//
//  WatchSyncBridge.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Riceve le mutazioni di sessione dal Watch (via PhoneConnector) e le
//  applica allo store SwiftData dell'iPhone + all'outbox verso il backend
//  (ADR-0016: il Watch sincronizza solo con l'iPhone; l'iPhone è l'hub).
//

import Foundation
import SwiftData

@MainActor
final class WatchSyncBridge {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
        PhoneConnector.shared.onMessage = { [weak self] msg in
            self?.handle(msg)
        }
    }

    /// Instrada un evento dal Watch. `internal` per i test.
    func handle(_ msg: [String: Any]) {
        guard let type = msg["type"] as? String else { return }
        switch type {
        case "session.start":  startSession(msg)
        case "setlog.create":  logSet(msg)
        case "session.pause":  setStatus(msg, .paused)
        case "session.resume": setStatus(msg, .active)
        case "session.end":    endSession(msg)
        default: break
        }
        Task { await GymSync.flushOutbox(context) }
    }

    private func startSession(_ msg: [String: Any]) {
        guard let id = uuid(msg["id"]) else { return }
        if fetchSession(id) != nil { return }
        let started = (msg["startedAt"] as? String).flatMap(JSONDecoder.iso.date(from:)) ?? .now
        let s = WorkoutSession(id: id, startedAt: started, source: "watch")
        context.insert(s)
        enqueue("session.create", ["id": id.uuidString, "source": "watch"])
    }

    private func logSet(_ msg: [String: Any]) {
        guard let id = uuid(msg["id"]),
              let sessionId = uuid(msg["sessionId"]),
              let session = fetchSession(sessionId),
              let weight = number(msg["weightKg"]),
              let reps = int(msg["reps"]) else { return }
        let name = (msg["exerciseName"] as? String)?.trimmingCharacters(in: .whitespaces)
        let exName = (name?.isEmpty == false) ? name! : "Serie libera"
        let exercise = resolveExercise(named: exName)
        let allSets = (try? context.fetch(FetchDescriptor<SetLogEntry>())) ?? []
        let sameCount = allSets.filter { $0.session?.id == sessionId && $0.exerciseId == exercise.id }.count
        let idx = int(msg["setIndex"]) ?? (sameCount + 1)

        let entry = SetLogEntry(
            id: id, session: session, exerciseId: exercise.id, exerciseName: exercise.name,
            setIndex: idx, weightKg: weight, reps: reps
        )
        context.insert(entry)
        enqueue("setlog.create", [
            "id": id.uuidString, "sessionId": sessionId.uuidString,
            "exerciseId": exercise.id.uuidString, "setIndex": idx,
            "weightKg": weight, "reps": reps,
        ])
    }

    private func setStatus(_ msg: [String: Any], _ status: SessionStatus) {
        guard let id = uuid(msg["id"]), let session = fetchSession(id) else { return }
        session.status = status
        session.syncedAt = nil
        enqueue("session.update", ["id": id.uuidString, "status": status.rawValue])
    }

    private func endSession(_ msg: [String: Any]) {
        guard let id = uuid(msg["id"]), let session = fetchSession(id) else { return }
        let status = (msg["status"] as? String) == "cancelled" ? SessionStatus.cancelled : .completed
        let start = session.startedAt
        let finish = Date()
        session.status = status
        session.endedAt = finish
        session.syncedAt = nil
        enqueue("session.update", ["id": id.uuidString, "status": status.rawValue])
        // sessioni cancelled escluse da Salute (ADR-0016). Se il Watch ha già
        // salvato l'`HKWorkout` (HealthKit attivo al polso), l'iPhone non ne
        // crea un duplicato — fallback solo se `hkSaved` non è true.
        if status == .completed, (msg["hkSaved"] as? Bool) != true {
            Task { await HealthKitService.shared.saveCompletedWorkout(start: start, end: finish, activeEnergyKcal: nil) }
        }
    }

    // MARK: helpers

    private func resolveExercise(named name: String) -> Exercise {
        if let e = try? context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        ).first { return e }
        let e = Exercise(name: name)
        context.insert(e)
        enqueue("exercise.create", ["id": e.id.uuidString, "name": name, "muscleGroups": [String]()])
        return e
    }

    private func fetchSession(_ id: UUID) -> WorkoutSession? {
        try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == id })).first
    }
    private func enqueue(_ kind: String, _ payload: [String: Any]) {
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: kind, payload: data))
        }
        try? context.save()
    }
    private func uuid(_ v: Any?) -> UUID? { (v as? String).flatMap(UUID.init(uuidString:)) }
    private func number(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue ?? (v as? Double) }
    private func int(_ v: Any?) -> Int? { (v as? NSNumber)?.intValue ?? (v as? Int) }
}
