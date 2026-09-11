//
//  DBTargetPreference.swift
//  1r0-pkm · Modules/Shared/API
//
//  Interruttore "usa il database di sviluppo" (ADR-0034): il backend ha due
//  database sullo stesso Postgres — prod (dati reali, ADR-0033) e dev/test.
//  Acceso, `ApiClient` manda `X-Db-Target: dev` su ogni richiesta e il
//  backend instrada al pool giusto per quella richiesta (db.js). Locale,
//  `UserDefaults` — non sincronizzato, non c'entra con l'outbox.
//
//  Nota: cambiare target non svuota la cache locale SwiftData — i dati
//  dell'altro database restano mescolati finché l'app non riparte da uno
//  store pulito (stesso limite di ogni cambio di store locale in questa app).
//

import Foundation

enum DBTargetPreference {
    private static let key = "api.dbTarget.dev"

    static func isDevEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: key)
    }

    static func setDevEnabled(_ enabled: Bool, _ defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: key)
    }
}
