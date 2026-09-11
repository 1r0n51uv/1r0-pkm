//
//  MissingMealReminder.swift
//  1r0-pkm · Modules/1r0-diet/Reminders
//
//  Promemoria "pasto mancante" (glossario): per ogni MealSlot con un orario
//  atteso, se a quell'ora (+ tolleranza) non c'è né un `MealEntry` né un Meal
//  Slot Ack per la giornata, notifica azionabile "«Slot»?" con "Sì" / "Rimanda".
//
//  Gli orari sono un default ragionevole; ADR-0024 (5 slot) e l'override utente
//  arrivano con lo step 4 — la regola itera comunque `MealSlot.allCases`, quindi
//  eredita i nuovi slot appena esistono.
//

import Foundation
import SwiftData

@MainActor
struct MissingMealReminder: ReminderRule {
    var category: ReminderCategory { .missingMeal }

    /// Store degli ack (iniettabile nei test).
    var acksDefaults: UserDefaults = .standard

    /// Ora del giorno attesa per slot. Slot senza voce → nessun promemoria
    /// (es. `snack` generico, senza orario significativo).
    static let expectedHour: [MealSlot: (h: Int, m: Int)] = [
        .breakfast: (9, 30),
        .lunch: (13, 0),
        .dinner: (20, 0),
    ]

    /// Minuti di tolleranza dopo l'orario atteso prima di notificare.
    static let graceMinutes = 30

    func plan(now: Date, context: ModelContext, env: ReminderEnv) -> [PlannedNotification] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let stamp = MealSlotAck.stamp(now, calendar: cal)

        let meals = (try? context.fetch(FetchDescriptor<MealEntry>())) ?? []
        let loggedToday = Set(
            meals.filter { cal.isDate($0.consumedAt, inSameDayAs: now) }.map(\.mealSlot)
        )

        var out: [PlannedNotification] = []
        for slot in MealSlot.allCases {
            guard let hm = Self.expectedHour[slot],
                  let base = cal.date(bySettingHour: hm.h, minute: hm.m, second: 0, of: today)
            else { continue }
            let fireAt = base.addingTimeInterval(Double(Self.graceMinutes) * 60)

            guard fireAt > now else { continue }                 // orario già passato oggi
            guard !loggedToday.contains(slot) else { continue }  // già loggato
            guard !MealSlotAck.isAcked(slotRaw: slot.rawValue, dayStamp: stamp, defaults: acksDefaults) else { continue }

            out.append(PlannedNotification(
                id: "\(category.requestPrefix)\(slot.rawValue).\(stamp)",
                category: category,
                title: "\(slot.label)?",
                body: "Non hai ancora segnato \(slot.label.lowercased()) oggi.",
                fireDate: fireAt,
                userInfo: ["slot": slot.rawValue, "day": stamp]
            ))
        }
        return out
    }

    func handleAction(_ actionId: String, userInfo: [AnyHashable: Any], context: ModelContext) async {
        guard actionId == ReminderAction.ate,
              let slot = userInfo["slot"] as? String,
              let day = userInfo["day"] as? String else { return }
        MealSlotAck.record(slotRaw: slot, dayStamp: day, defaults: acksDefaults)
    }
}
