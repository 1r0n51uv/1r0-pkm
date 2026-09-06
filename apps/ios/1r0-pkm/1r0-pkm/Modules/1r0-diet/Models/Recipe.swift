//
//  Recipe.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Pasto riutilizzabile (glossario: "Recipe", ADR-0017 slice 2): un elenco
//  di alimenti con quantità, da richiamare quando si logga o si pianifica un
//  pasto senza ricomporlo ogni volta. Gli item *snapshottano* il nome
//  (migration 0008) per restare leggibili offline; i macro si calcolano dal
//  `Food` collegato al momento dell'uso (non snapshottati qui — al log sì).
//

import Foundation
import SwiftData

@Model
final class Recipe {
    @Attribute(.unique) var id: UUID
    var name: String
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    /// `nil` finché il backend non conferma la riga (outbox, ADR-0006).
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \RecipeItem.recipe)
    var items: [RecipeItem] = []

    init(id: UUID = UUID(), name: String, notes: String? = nil,
         createdAt: Date = .now, updatedAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncedAt = syncedAt
    }

    /// Macro totali, calcolate al volo dai `Food` passati (mappa id→Food).
    func totals(foods: [UUID: Food]) -> Macros {
        items.reduce(.zero) { acc, it in
            guard let f = it.foodId.flatMap({ foods[$0] }) else { return acc }
            return acc + f.macros(forGrams: it.quantityG)
        }
    }
}

@Model
final class RecipeItem {
    @Attribute(.unique) var id: UUID
    var recipe: Recipe?
    /// `nil` se il `Food` è stato cancellato: `foodName` + `quantityG` restano.
    var foodId: UUID?
    var foodName: String = ""
    var quantityG: Double = 0
    var orderIndex: Int = 0

    init(id: UUID = UUID(), recipe: Recipe? = nil, foodId: UUID? = nil,
         foodName: String, quantityG: Double, orderIndex: Int = 0) {
        self.id = id
        self.recipe = recipe
        self.foodId = foodId
        self.foodName = foodName
        self.quantityG = quantityG
        self.orderIndex = orderIndex
    }
}
