//
//  ShoppingListItem.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Voce di lista della spesa (glossario: "Shopping List Item", ADR-0017
//  slice 3): persistente e spuntabile. `source` = `generated` (creata dai
//  pasti pianificati della settimana) o `manual`. La generazione *aggiunge*
//  soltanto: non rigenera né sovrascrive le voci esistenti.
//

import Foundation
import SwiftData

enum ShoppingSource: String, Codable { case generated, manual }

@Model
final class ShoppingListItem {
    @Attribute(.unique) var id: UUID
    /// se legata a un `Food`; altrimenti si usa `customName`.
    var foodId: UUID?
    var customName: String = ""
    var quantityText: String?
    var isChecked: Bool = false
    var sourceRaw: String = ShoppingSource.manual.rawValue
    var createdAt: Date
    /// `nil` finché il backend non conferma la riga (outbox, ADR-0006).
    var syncedAt: Date?

    var source: ShoppingSource {
        get { ShoppingSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }
    /// Nome mostrato: `customName` (le voci generate ci copiano il nome del food).
    var displayName: String { customName }

    init(id: UUID = UUID(), foodId: UUID? = nil, customName: String,
         quantityText: String? = nil, isChecked: Bool = false,
         source: ShoppingSource = .manual, createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.foodId = foodId
        self.customName = customName
        self.quantityText = quantityText
        self.isChecked = isChecked
        self.sourceRaw = source.rawValue
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}
