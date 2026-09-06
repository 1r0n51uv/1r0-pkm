//
//  Food.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Un alimento del catalogo (glossario: "Food"), con macro per 100 g.
//  `source`: `openfoodfacts` | `usda` | `custom` (ADR-0018). Slice 1
//  (ADR-0017) usa solo `custom`; barcode/OpenFoodFacts/USDA più avanti.
//

import Foundation
import SwiftData

@Model
final class Food {
    @Attribute(.unique) var id: UUID
    var name: String
    /// "openfoodfacts" | "usda" | "custom". Default in dichiarazione per la
    /// migrazione lightweight (come `Exercise.source`, ADR-0005).
    var source: String = "custom"
    /// id nella fonte esterna, per re-sync. `nil` per custom.
    var externalId: String?
    var barcode: String?
    var brand: String?
    var servingSizeG: Double?
    var caloriesPer100g: Double
    var proteinGPer100g: Double
    var carbsGPer100g: Double
    var fatGPer100g: Double
    var caffeineMgPer100g: Double?
    var createdAt: Date
    /// `nil` finché il backend non conferma la riga (outbox, ADR-0006).
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        source: String = "custom",
        externalId: String? = nil,
        barcode: String? = nil,
        brand: String? = nil,
        servingSizeG: Double? = nil,
        caloriesPer100g: Double,
        proteinGPer100g: Double = 0,
        carbsGPer100g: Double = 0,
        fatGPer100g: Double = 0,
        caffeineMgPer100g: Double? = nil,
        createdAt: Date = .now,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.externalId = externalId
        self.barcode = barcode
        self.brand = brand
        self.servingSizeG = servingSizeG
        self.caloriesPer100g = caloriesPer100g
        self.proteinGPer100g = proteinGPer100g
        self.carbsGPer100g = carbsGPer100g
        self.fatGPer100g = fatGPer100g
        self.caffeineMgPer100g = caffeineMgPer100g
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }

    /// Macro per una quantità in grammi.
    func macros(forGrams g: Double) -> Macros {
        let k = g / 100
        return Macros(kcal: caloriesPer100g * k,
                      proteinG: proteinGPer100g * k,
                      carbsG: carbsGPer100g * k,
                      fatG: fatGPer100g * k)
    }
}

/// Valori nutrizionali assoluti (ADR-0019: grammi, non percentuali).
struct Macros: Equatable {
    var kcal: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double

    static let zero = Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)
    static func + (a: Macros, b: Macros) -> Macros {
        Macros(kcal: a.kcal + b.kcal, proteinG: a.proteinG + b.proteinG,
               carbsG: a.carbsG + b.carbsG, fatG: a.fatG + b.fatG)
    }
}
