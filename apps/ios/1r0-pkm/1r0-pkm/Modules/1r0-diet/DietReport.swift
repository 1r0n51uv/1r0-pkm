//
//  DietReport.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Aggregazioni per i report (ADR-0020): tutto lato client dai dati già
//  esistenti, nessuna tabella nuova. Funzioni pure → testabili in
//  isolamento (nessun SwiftData / rete qui, si passano gli array).
//

import Foundation

enum DietReport {

    struct Day: Identifiable {
        let date: Date            // mezzanotte locale
        var id: Date { date }
        let kcal: Double
        let macros: Macros
        let logged: Bool          // c'è almeno un item quel giorno
        /// obiettivo kcal attivo *in quel giorno* (storico, ADR-0020), se c'è.
        var goalKcal: Double?
    }

    /// Serie giornaliera di calorie/macro per la finestra `days` (incluso
    /// oggi), dal più vecchio al più recente. Giorni senza log → kcal 0.
    static func dailySeries(meals: [MealEntry], goals: [NutritionGoal],
                            days: Int, now: Date = .now) -> [Day] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        var byDay: [Date: (Macros, Bool)] = [:]
        for m in meals {
            let d = cal.startOfDay(for: m.consumedAt)
            guard let diff = cal.dateComponents([.day], from: d, to: today).day,
                  diff >= 0, diff < days else { continue }
            let t = m.totals
            let prev = byDay[d] ?? (.zero, false)
            byDay[d] = (prev.0 + t, prev.1 || !m.items.isEmpty)
        }
        return (0..<days).reversed().compactMap { back in
            guard let d = cal.date(byAdding: .day, value: -back, to: today) else { return nil }
            let (mac, logged) = byDay[d] ?? (.zero, false)
            return Day(date: d, kcal: mac.kcal, macros: mac, logged: logged,
                       goalKcal: goalActive(goals, on: d)?.caloriesTarget)
        }
    }

    /// Obiettivo attivo in `day`: riga più recente con `effectiveFrom <= day`.
    static func goalActive(_ goals: [NutritionGoal], on day: Date) -> NutritionGoal? {
        let end = Calendar.current.startOfDay(for: day)
        return goals
            .filter { $0.effectiveFrom <= end }
            .max { ($0.effectiveFrom, $0.createdAt) < ($1.effectiveFrom, $1.createdAt) }
    }

    /// Media kcal sui soli giorni con log.
    static func averageKcal(_ series: [Day]) -> Double {
        let logged = series.filter(\.logged)
        guard !logged.isEmpty else { return 0 }
        return logged.reduce(0) { $0 + $1.kcal } / Double(logged.count)
    }

    /// Variazione kcal fra la prima e l'ultima terza parte della finestra
    /// (solo giorni con log). `nil` se non c'è abbastanza storico.
    static func trendKcal(_ series: [Day]) -> Double? {
        let logged = series.filter(\.logged)
        guard logged.count >= 4 else { return nil }
        let n = max(1, logged.count / 3)
        let first = logged.prefix(n).reduce(0) { $0 + $1.kcal } / Double(n)
        let last = logged.suffix(n).reduce(0) { $0 + $1.kcal } / Double(n)
        return last - first
    }

    struct Adherence { let inTarget: Int; let total: Int
        var pct: Double { total == 0 ? 0 : Double(inTarget) / Double(total) }
    }

    /// Giorni (con log + obiettivo) entro `toleranceKcal` dal target di quel
    /// giorno.
    static func adherence(_ series: [Day], toleranceKcal: Double = 150) -> Adherence {
        let eligible = series.filter { $0.logged && $0.goalKcal != nil }
        let hit = eligible.filter { abs($0.kcal - $0.goalKcal!) <= toleranceKcal }.count
        return Adherence(inTarget: hit, total: eligible.count)
    }

    struct WeightPoint: Identifiable { let date: Date; var id: Date { date }; let kg: Double }

    /// Serie peso nella finestra, dal più vecchio al più recente.
    static func weightSeries(_ measurements: [BodyMeasurement],
                             days: Int, now: Date = .now) -> [WeightPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        return measurements
            .compactMap { m -> WeightPoint? in
                guard let kg = m.weightKg else { return nil }
                let d = cal.startOfDay(for: m.recordedAt)
                guard let diff = cal.dateComponents([.day], from: d, to: today).day,
                      diff >= 0, diff < days else { return nil }
                return WeightPoint(date: d, kg: kg)
            }
            .sorted { $0.date < $1.date }
    }

    static func weightDelta(_ pts: [WeightPoint]) -> Double? {
        guard let f = pts.first, let l = pts.last, pts.count >= 2 else { return nil }
        return l.kg - f.kg
    }
}
