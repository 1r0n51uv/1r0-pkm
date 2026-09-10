//
//  ReminderSettings.swift
//  1r0-pkm · Modules/Shared/Reminders
//
//  Interruttore on/off per categoria di Promemoria (glossario: "Impostazioni
//  notifiche"). Preferenza puramente locale al device: niente sync, niente
//  storico → `UserDefaults`, non SwiftData.
//

import Foundation

struct ReminderSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ c: ReminderCategory) -> String { "reminders.\(c.rawValue).enabled" }

    /// Default: attiva. L'utente disattiva esplicitamente una categoria.
    func isEnabled(_ c: ReminderCategory) -> Bool {
        defaults.object(forKey: key(c)) as? Bool ?? true
    }

    func setEnabled(_ enabled: Bool, for c: ReminderCategory) {
        defaults.set(enabled, forKey: key(c))
    }
}
