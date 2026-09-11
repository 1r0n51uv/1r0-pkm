//
//  GymData.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Container SwiftData condiviso fra i moduli (ADR-0008).
//

import Foundation
import SwiftData

enum GymData {
    static let schema = Schema([
        // ADR-0027: `Exercise`/`Routine`/`RoutineDay`/`RoutineExercise`/`PlateConfig`
        // rimossi col catalogo/editor schede. `WorkoutSession`/`SetLogEntry`
        // sono ora record **importati read-only** dal CSV Liftin' (gym reshape,
        // step 3): niente lifecycle, `reps` opzionale, + `durationSeconds`/
        // `isWarmup`.
        WorkoutSession.self, SetLogEntry.self,
        BodyMeasurement.self, OutboxEntry.self,
        // Modulo 1r0-diet (ADR-0017): container unico, ADR-0008.
        Food.self, MealEntry.self, MealEntryItem.self, NutritionGoal.self,
        Recipe.self, RecipeItem.self, PlannedMeal.self, PlannedMealItem.self,
        ShoppingListItem.self,
        WaterLog.self, Supplement.self, SupplementLog.self, CaffeineLog.self,
        // ADR-0029: dieta settimanale a template.
        DietTemplate.self, DietTemplateItem.self,
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
