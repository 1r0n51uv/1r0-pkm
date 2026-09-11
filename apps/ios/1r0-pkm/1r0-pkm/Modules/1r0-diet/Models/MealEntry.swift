//
//  MealEntry.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Un pasto consumato e loggato (glossario: "Meal Entry"), con `mealSlot` a
//  5 valori (ADR-0024: colazione/spuntino mattina/pranzo/spuntino pomeriggio/
//  cena — "snack" generico rimosso). Composto da `MealEntryItem`, che
//  *snapshotta* calorie/macro al momento del log (ADR-0017): restano
//  storicamente accurati anche se il `Food` viene corretto dopo.
//

import Foundation
import SwiftData

enum MealSlot: String, CaseIterable, Identifiable, Codable {
    case breakfast
    case morningSnack = "morning_snack"
    case lunch
    case afternoonSnack = "afternoon_snack"
    case dinner
    var id: String { rawValue }
    var label: String {
        switch self {
        case .breakfast: return "Colazione"
        case .morningSnack: return "Spuntino mattina"
        case .lunch: return "Pranzo"
        case .afternoonSnack: return "Spuntino pomeriggio"
        case .dinner: return "Cena"
        }
    }
    var systemImage: String {
        switch self {
        case .breakfast: return "sun.horizon.fill"
        case .morningSnack: return "carrot.fill"
        case .lunch: return "sun.max.fill"
        case .afternoonSnack: return "carrot.fill"
        case .dinner: return "moon.stars.fill"
        }
    }
    /// Ordine di visualizzazione nella giornata.
    var order: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}

@Model
final class MealEntry {
    @Attribute(.unique) var id: UUID
    var consumedAt: Date
    /// grezzo: uno dei rawValue di `MealSlot` (ADR-0024).
    var mealSlotRaw: String = MealSlot.lunch.rawValue
    var notes: String?
    var createdAt: Date
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \MealEntryItem.meal)
    var items: [MealEntryItem] = []

    var mealSlot: MealSlot {
        get { MealSlot(rawValue: mealSlotRaw) ?? .lunch }
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
