//
//  HealthKitPreference.swift
//  1r0-pkm · Modules/Shared/HealthKit
//
//  Interruttore esplicito "Collega Apple Salute" per il modulo diet
//  (ADR-0029), separato dal permesso di sistema: quando spento, `DietSync` e
//  `DietTabView` non chiamano affatto `HealthKitService` (niente richiesta
//  permessi, niente lettura/scrittura). Locale, `UserDefaults` — non
//  sincronizzato.
//

import Foundation

enum HealthKitPreference {
    private static let key = "diet.healthkit.enabled"

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func setEnabled(_ enabled: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: key)
    }
}
