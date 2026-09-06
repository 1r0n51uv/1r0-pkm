//
//  GymData.swift · GymActions.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Container SwiftData condiviso fra App e App Intents (ADR-0014), e le
//  azioni di dominio riusate da UI, Watch bridge e Intent.
//

import Foundation
import SwiftData

enum GymData {
    static let schema = Schema([
        Exercise.self, Routine.self, RoutineDay.self, RoutineExercise.self,
        WorkoutSession.self, SetLogEntry.self,
        PlateConfig.self, BodyMeasurement.self, OutboxEntry.self,
    ])

    /// Container reale (on-disk). `var` così i test lo sostituiscono con uno
    /// in-memory.
    static var container: ModelContainer = {
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("GymData container non creato: \(error)")
        }
    }()
}

@MainActor
enum GymActions {
    /// Crea una `WorkoutSession` come farebbe l'avvio manuale + accoda
    /// `session.create` all'outbox. Usata da UI e da `StartWorkoutIntent`.
    @discardableResult
    static func startWorkout(
        routineDayId: UUID? = nil,
        source: String = "app",
        in context: ModelContext
    ) -> WorkoutSession {
        let s = WorkoutSession(source: source, routineDayId: routineDayId)
        context.insert(s)

        var payload: [String: Any] = ["id": s.id.uuidString, "source": source]
        if let routineDayId { payload["routineDayId"] = routineDayId.uuidString }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            context.insert(OutboxEntry(kind: "session.create", payload: data))
        }
        try? context.save()

        let ctx = context
        Task { await GymSync.flushOutbox(ctx) }
        return s
    }
}
