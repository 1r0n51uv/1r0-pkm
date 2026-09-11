//
//  DietTemplate.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Dieta settimanale (ADR-0029): un template riutilizzabile — una ricetta per
//  ciascuno dei 5 slot (ADR-0024) di ciascun giorno della settimana — che si
//  **applica** a settimane specifiche (genera i `PlannedMeal` di quella
//  settimana, `DietSync.applyTemplate`). Il template stesso resta locale
//  (nessun outbox): a sincronizzare sono i `PlannedMeal` che produce.
//

import Foundation
import SwiftData

@Model
final class DietTemplate {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DietTemplateItem.template)
    var items: [DietTemplateItem] = []

    init(id: UUID = UUID(), name: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    func item(weekday: Int, slot: MealSlot) -> DietTemplateItem? {
        items.first { $0.weekday == weekday && $0.mealSlot == slot }
    }
}

@Model
final class DietTemplateItem {
    @Attribute(.unique) var id: UUID
    var template: DietTemplate?
    /// 1 = lunedì … 7 = domenica (ISO, come `Calendar.current` con `firstWeekday` IT).
    var weekday: Int
    var mealSlotRaw: String = MealSlot.lunch.rawValue
    /// `nil` = slot del template lasciato vuoto (nessun pasto quel giorno).
    var recipeId: UUID?
    /// Nome della ricetta al momento dell'assegnazione — leggibile anche se
    /// la ricetta viene rinominata/cancellata dopo.
    var recipeName: String?

    var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .lunch }
        set { mealSlotRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(), template: DietTemplate? = nil, weekday: Int, mealSlot: MealSlot,
         recipeId: UUID? = nil, recipeName: String? = nil) {
        self.id = id
        self.template = template
        self.weekday = weekday
        self.mealSlotRaw = mealSlot.rawValue
        self.recipeId = recipeId
        self.recipeName = recipeName
    }
}
