//
//  WaterReminder.swift
//  1r0-pkm · Modules/1r0-diet/Reminders
//
//  Promemoria acqua (glossario): a orari fissi della fascia diurna, se il
//  totale bevuto oggi (WaterLog locale + HealthKit) è sotto la quota
//  proporzionata all'ora, manda un nudge "Hai bevuto?". Nessuna azione: è un
//  promemoria semplice. Dipende dal motore Promemoria (ADR-0027 step 2/4).
//

import Foundation
import SwiftData

@MainActor
struct WaterReminder: ReminderRule {
    var category: ReminderCategory { .water }

    /// Usato se `NutritionGoal.waterMlTarget` non è impostato.
    static let defaultTargetMl = 2000.0
    /// Orari a cui vale la pena controllare (fascia diurna).
    static let checkHours = [11, 14, 17, 20]

    func plan(now: Date, context: ModelContext, env: ReminderEnv) -> [PlannedNotification] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let stamp = MealSlotAck.stamp(now, calendar: cal)

        let goals = (try? context.fetch(FetchDescriptor<NutritionGoal>(
            sortBy: [SortDescriptor(\.effectiveFrom, order: .reverse)]))) ?? []
        let target = goals.first(where: { $0.effectiveFrom <= now })?.waterMlTarget
            ?? Self.defaultTargetMl

        let waterLogs = (try? context.fetch(FetchDescriptor<WaterLog>())) ?? []
        let localMl = waterLogs
            .filter { cal.isDate($0.loggedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.amountMl }
        let consumed = localMl + (env.healthKitWaterMl ?? 0)

        // Prossimo orario di check ancora futuro oggi.
        guard let nextHour = Self.checkHours.first(where: { hour in
            (cal.date(bySettingHour: hour, minute: 0, second: 0, of: today) ?? now) > now
        }),
        let fireAt = cal.date(bySettingHour: nextHour, minute: 0, second: 0, of: today)
        else { return [] }

        let quota = NutritionMath.waterQuotaMl(targetMl: target, now: fireAt)
        guard consumed < quota else { return [] }

        return [PlannedNotification(
            id: "\(category.requestPrefix)\(stamp)",
            category: category,
            title: "Hai bevuto?",
            body: "Sei sotto la quota d'acqua di oggi (\(Int(consumed)) / \(Int(quota)) ml).",
            fireDate: fireAt
        )]
    }
}
