//
//  ReminderRule.swift
//  1r0-pkm · Modules/Shared/Reminders
//
//  Una regola di Promemoria (glossario): "l'utente doveva fare X e non l'ha
//  fatto", valutata sui dati già presenti. La regola non schedula nulla di
//  suo — restituisce le notifiche che *dovrebbero* essere pendenti a partire
//  da `now`; `RemindersEngine` fa il diff con quelle realmente in coda e
//  aggiunge/cancella di conseguenza.
//

import Foundation
import SwiftData

/// Valori pre-caricati (asincroni) che le regole non possono leggere da sole
/// dentro `plan` (che è sincrono). `RemindersEngine` li recupera prima del
/// giro e li passa a ogni regola.
struct ReminderEnv: Sendable {
    var healthKitWaterMl: Double?
    var activeEnergyKcal: Double?
}

/// Una notifica che una regola vuole vedere schedulata.
struct PlannedNotification: Equatable, Sendable {
    /// Identificatore stabile e deterministico per `(regola, slot, giorno)`,
    /// con prefisso `category.requestPrefix` così il motore lo riconosce come
    /// suo. Ripianificare con lo stesso id sostituisce la richiesta.
    let id: String
    let category: ReminderCategory
    let title: String
    let body: String
    let fireDate: Date
    /// Copiato in `content.userInfo` — usato dagli handler delle azioni.
    var userInfo: [String: String] = [:]
}

@MainActor
protocol ReminderRule {
    var category: ReminderCategory { get }

    /// Le notifiche che dovrebbero essere pendenti valutando lo stato a `now`.
    /// Solo istanze con `fireDate > now`. Pura rispetto alla rete; legge da
    /// SwiftData (`context`), `UserDefaults` ed `env` (valori HealthKit
    /// pre-caricati).
    func plan(now: Date, context: ModelContext, env: ReminderEnv) -> [PlannedNotification]

    /// Risposta a un'azione custom della categoria (gestita in background).
    /// Lo "snooze" generico è gestito dal motore; qui arriva il resto (es.
    /// "Sì" → Meal Slot Ack). Default: nessun effetto.
    func handleAction(_ actionId: String, userInfo: [AnyHashable: Any], context: ModelContext) async
}

extension ReminderRule {
    func handleAction(_ actionId: String, userInfo: [AnyHashable: Any], context: ModelContext) async {}
}
