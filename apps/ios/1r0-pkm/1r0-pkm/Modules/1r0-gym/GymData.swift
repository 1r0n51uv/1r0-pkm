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
        // Modulo 1r0-diet (ADR-0017): container unico, ADR-0008.
        Food.self, MealEntry.self, MealEntryItem.self, NutritionGoal.self,
        Recipe.self, RecipeItem.self, PlannedMeal.self, PlannedMealItem.self,
        ShoppingListItem.self,
        WaterLog.self, Supplement.self, SupplementLog.self, CaffeineLog.self,
    ])

    /// Container condiviso. In-memory sotto i test UI (`-uitest-reset`),
    /// altrimenti on-disk. `var` così i test possono comunque sostituirlo.
    static var container: ModelContainer = makeContainer()

    static func makeContainer() -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-uitest-reset")
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema drift sullo store locale (es. nuovo attributo non
            // opzionale): i dati veri stanno sul backend (ADR-0006), meglio
            // ripartire da vuoto che non far partire l'app. Solo on-disk.
            if !inMemory {
                let url = URL.applicationSupportDirectory.appending(path: "default.store")
                for ext in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + ext))
                }
                if let recovered = try? ModelContainer(for: schema, configurations: config) {
                    return recovered
                }
            }
            fatalError("GymData container non creato: \(error)")
        }
    }
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
