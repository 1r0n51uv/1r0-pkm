//
//  MealSlotAck.swift
//  1r0-pkm · Modules/1r0-diet/Reminders
//
//  Meal Slot Ack (glossario): flag "slot ok oggi" registrato quando l'utente
//  risponde "Sì" al promemoria pasto mancante. Silenzia il promemoria di quel
//  MealSlot per la giornata **senza** creare un `MealEntry`.
//
//  È uno stato effimero (un giorno), locale, non sincronizzato → `UserDefaults`.
//  Se lo step 4 avrà bisogno di storicizzarlo per i report può promuoverlo a
//  `@Model`; per ora questo basta.
//

import Foundation

enum MealSlotAck {
    private static let key = "diet.mealSlotAcks"

    /// Data civile come `yyyy-MM-dd` (calendario locale).
    static func stamp(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func token(slotRaw: String, dayStamp: String) -> String {
        "\(dayStamp)|\(slotRaw)"
    }

    static func isAcked(slotRaw: String, dayStamp: String,
                        defaults: UserDefaults = .standard) -> Bool {
        let stored = defaults.array(forKey: key) as? [String] ?? []
        return stored.contains(token(slotRaw: slotRaw, dayStamp: dayStamp))
    }

    static func record(slotRaw: String, dayStamp: String, now: Date = .now,
                       defaults: UserDefaults = .standard) {
        var set = Set(defaults.array(forKey: key) as? [String] ?? [])
        set.insert(token(slotRaw: slotRaw, dayStamp: dayStamp))
        // tiene solo gli ack degli ultimi ~3 giorni (il token inizia con la data)
        let keep = (0...3).map { stamp(now.addingTimeInterval(Double(-$0) * 86_400)) }
        set = set.filter { tok in keep.contains(where: { tok.hasPrefix("\($0)|") }) }
        defaults.set(Array(set), forKey: key)
    }
}
