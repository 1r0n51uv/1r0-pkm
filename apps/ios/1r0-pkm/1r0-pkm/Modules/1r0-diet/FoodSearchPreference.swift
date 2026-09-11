//
//  FoodSearchPreference.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Filtro "solo Italia" per la ricerca alimenti (ADR-0036): la ricerca
//  OpenFoodFacts globale (world.openfoodfacts.org) restituisce prodotti di
//  qualunque paese — molti risultati francesi/spagnoli/tedeschi anche per
//  query in italiano ("pane", "bread"). Acceso di default: il backend usa
//  il sottodominio nazionale (`&country=it`, `apps/api/src/routes/foodsearch.js`),
//  che restringe ai prodotti taggati Italia. Locale, `UserDefaults`.
//

import Foundation

enum FoodSearchPreference {
    private static let key = "diet.foodSearch.italianOnly"

    /// Acceso di default (nessuna voce salvata ancora) — è la richiesta
    /// esplicita dell'utente, non un'opzione da scoprire in Impostazioni.
    static func isItalianOnly(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: key) == nil ? true : defaults.bool(forKey: key)
    }

    static func setItalianOnly(_ enabled: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: key)
    }
}
