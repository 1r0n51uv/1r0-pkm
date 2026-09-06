//
//  MealEntry.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Un pasto consumato e loggato (glossario: "Meal Entry"), con `mealSlot`
//  (breakfast/lunch/dinner/snack). Composto da `MealEntryItem`, che
//  *snapshotta* calorie/macro al momento del log (ADR-0017): restano
//  storicamente accurati anche se il `Food` viene corretto dopo.
//

import Foundation
import SwiftData

enum MealSlot: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: return "Colazione"
        case .lunch: return "Pranzo"
        case .dinner: return "Cena"
        case .snack: return "Spuntino"
        }
    }
    var systemImage: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "carrot.fill"
        }
    }
    /// Ordine di visualizzazione nella giornata.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

@Model
final class MealEntry {
    @Attribute(.unique) var id: UUID
    var consumedAt: Date
    /// grezzo: "breakfast" | "lunch" | "dinner" | "snack".
    var mealSlotRaw: String = MealSlot.snack.rawValue
    var notes: String?
    var createdAt: Date
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \MealEntryItem.meal)
    var items: [MealEntryItem] = []

    var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .snack }
        set { mealSlotRaw = newValue.rawValue }
    }

    var totals: Macros {
        items.reduce(.zero) { $0 + Macros(kcal: $1.calories, proteinG: $1.proteinG,
                                          carbsG: $1.carbsG, fatG: $1.fatG) }
    }

    init(id: UUID = UUID(), consumedAt: Date = .now, mealSlot: MealSlot,
         notes: String? = nil, createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.consumedAt = consumedAt
        self.mealSlotRaw = mealSlot.rawValue
        self.notes = notes
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}

@Model
final class MealEntryItem {
    @Attribute(.unique) var id: UUID
    var meal: MealEntry?
    /// `nil` se il `Food` è stato cancellato: i macro sotto restano.
    var foodId: UUID?
    var foodName: String = ""
    var quantityG: Double = 0
    /// Snapshot al momento del log (ADR-0017).
    var calories: Double = 0
    var proteinG: Double = 0
    var carbsG: Double = 0
    var fatG: Double = 0
    var orderIndex: Int = 0

    init(id: UUID = UUID(), meal: MealEntry? = nil, foodId: UUID? = nil,
         foodName: String, quantityG: Double, macros: Macros, orderIndex: Int = 0) {
        self.id = id
        self.meal = meal
        self.foodId = foodId
        self.foodName = foodName
        self.quantityG = quantityG
        self.calories = macros.kcal
        self.proteinG = macros.proteinG
        self.carbsG = macros.carbsG
        self.fatG = macros.fatG
        self.orderIndex = orderIndex
    }
}
