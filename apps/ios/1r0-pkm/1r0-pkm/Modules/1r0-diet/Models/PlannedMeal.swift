//
//  PlannedMeal.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Pasto pianificato per una data futura (glossario: "Planned Meal",
//  ADR-0017 slice 2). Confermarlo ("completed") crea un `MealEntry`
//  collegato (`mealEntryId`); saltarlo lo mette "skipped". Nessuna
//  rigenerazione automatica dalla lista spesa o dai giorni.
//

import Foundation
import SwiftData

enum PlanStatus: String, CaseIterable, Codable {
    case planned, completed, skipped
    var label: String {
        switch self {
        case .planned: return "Pianificato"
        case .completed: return "Mangiato"
        case .skipped: return "Saltato"
        }
    }
}

@Model
final class PlannedMeal {
    @Attribute(.unique) var id: UUID
    /// mezzanotte locale del giorno pianificato.
    var plannedDate: Date
    var mealSlotRaw: String = MealSlot.lunch.rawValue
    var statusRaw: String = PlanStatus.planned.rawValue
    var recipeId: UUID?
    /// il `MealEntry` generato alla conferma (glossario).
    var mealEntryId: UUID?
    var createdAt: Date
    /// `nil` finché il backend non conferma la riga (outbox, ADR-0006).
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PlannedMealItem.plannedMeal)
    var items: [PlannedMealItem] = []

    var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .lunch }
        set { mealSlotRaw = newValue.rawValue }
    }
    var status: PlanStatus {
        get { PlanStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), plannedDate: Date, mealSlot: MealSlot,
         status: PlanStatus = .planned, recipeId: UUID? = nil,
         mealEntryId: UUID? = nil, createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.plannedDate = plannedDate
        self.mealSlotRaw = mealSlot.rawValue
        self.statusRaw = status.rawValue
        self.recipeId = recipeId
        self.mealEntryId = mealEntryId
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }

    func totals(foods: [UUID: Food]) -> Macros {
        items.reduce(.zero) { acc, it in
            guard let f = it.foodId.flatMap({ foods[$0] }) else { return acc }
            return acc + f.macros(forGrams: it.quantityG)
        }
    }
}

@Model
final class PlannedMealItem {
    @Attribute(.unique) var id: UUID
    var plannedMeal: PlannedMeal?
    var foodId: UUID?
    var foodName: String = ""
    var quantityG: Double = 0
    var orderIndex: Int = 0

    init(id: UUID = UUID(), plannedMeal: PlannedMeal? = nil, foodId: UUID? = nil,
         foodName: String, quantityG: Double, orderIndex: Int = 0) {
        self.id = id
        self.plannedMeal = plannedMeal
        self.foodId = foodId
        self.foodName = foodName
        self.quantityG = quantityG
        self.orderIndex = orderIndex
    }
}
