//
//  ReminderCategory.swift
//  1r0-pkm · Modules/Shared/Reminders
//
//  Categorie di Promemoria (glossario). Un interruttore per categoria nelle
//  impostazioni notifiche — non per singola istanza (ADR-0027).
//

import Foundation

enum ReminderCategory: String, CaseIterable, Identifiable, Sendable {
    case missingMeal = "missing-meal"
    case water = "water"
    case documentExpiry = "document-expiry"

    var id: String { rawValue }

    /// Identificatore della `UNNotificationCategory` di sistema.
    var notificationCategoryId: String { "reminder.\(rawValue)" }

    /// Prefisso degli identificatori di richiesta che questa categoria possiede.
    /// Il motore riconcilia (aggiunge/cancella) solo le richieste con questo
    /// prefisso, per non toccare notifiche di altra origine.
    var requestPrefix: String { "\(rawValue)." }

    var label: String {
        switch self {
        case .missingMeal: return "Pasto mancante"
        case .water: return "Acqua"
        case .documentExpiry: return "Documenti"
        }
    }
}
