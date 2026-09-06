//
//  GymMath.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Regole di dominio pure (glossario: "PR / 1RM stimato", "Volume").
//  Calcolo locale, offline, nessuna AI (ADR-0011). Coperte da unit test.
//

import Foundation

enum GymMath {
    /// 1RM stimato — formula di Epley: `w * (1 + reps/30)`.
    /// A 1 rep ritorna il peso stesso. reps <= 0 o w < 0 ⇒ 0.
    static func epley1RM(weightKg w: Double, reps: Int) -> Double {
        guard w >= 0, reps > 0 else { return 0 }
        if reps == 1 { return w }
        return w * (1.0 + Double(reps) / 30.0)
    }

    /// Volume = somma di (peso × reps).
    static func volume<S: Sequence>(_ sets: S) -> Double where S.Element == (weightKg: Double, reps: Int) {
        sets.reduce(0) { $0 + $1.weightKg * Double($1.reps) }
    }

    /// Miglior 1RM stimato su un insieme di serie.
    static func bestEstimated1RM<S: Sequence>(_ sets: S) -> Double where S.Element == (weightKg: Double, reps: Int) {
        sets.reduce(0) { max($0, epley1RM(weightKg: $1.weightKg, reps: $1.reps)) }
    }

    // MARK: - Calcolatore piastre (ADR-0013)

    struct PlateLoad: Equatable {
        /// dischi per lato, dal più pesante al più leggero (con ripetizioni)
        let perSide: [Double]
        /// peso effettivamente caricabile (bilanciere + 2 × somma per lato)
        let achievable: Double
        /// quanto manca al target (>= 0)
        var leftover: Double
    }

    /// Dischi da mettere per lato per avvicinarsi a `targetKg`. I `plates`
    /// sono denominazioni disponibili (quantità illimitata per denominazione,
    /// come un vero calcolatore da palestra). Sceglie greedy dal più pesante.
    static func platesPerSide(targetKg: Double, barKg: Double, availablePlatesKg plates: [Double]) -> PlateLoad {
        guard targetKg > barKg else {
            return PlateLoad(perSide: [], achievable: barKg, leftover: max(0, targetKg - barKg))
        }
        let denom = plates.filter { $0 > 0 }.sorted(by: >)
        var remainingPerSide = (targetKg - barKg) / 2.0
        var side: [Double] = []
        // tolleranza numerica per i floating (0.001 kg)
        let eps = 0.001
        for p in denom {
            while remainingPerSide + eps >= p {
                side.append(p)
                remainingPerSide -= p
            }
        }
        let achievable = barKg + 2.0 * side.reduce(0, +)
        return PlateLoad(perSide: side, achievable: achievable, leftover: max(0, targetKg - achievable))
    }

    // MARK: - Warm-up automatico (ADR-0013)

    /// Percentuali fisse standard del peso di lavoro.
    static let warmupPercentages: [Double] = [0.4, 0.6, 0.8]

    struct WarmupStep: Equatable {
        let percent: Double
        let load: PlateLoad
    }

    /// Rampa di riscaldamento: per ogni percentuale, il peso caricabile più
    /// vicino (per difetto) con bilanciere + dischi disponibili.
    static func warmupRamp(workingWeightKg working: Double, barKg: Double, availablePlatesKg plates: [Double]) -> [WarmupStep] {
        warmupPercentages.map { pct in
            WarmupStep(percent: pct,
                       load: platesPerSide(targetKg: working * pct, barKg: barKg, availablePlatesKg: plates))
        }
    }

    // MARK: - Andamento peso corporeo (ADR-0012)

    struct WeightTrend: Equatable {
        let latestKg: Double
        /// variazione dal primo all'ultimo punto del range
        let deltaKg: Double
        /// variazione media per settimana sul range
        let perWeekKg: Double
    }

    /// Trend su punti (data, peso). Serve almeno un giorno di separazione fra
    /// il primo e l'ultimo punto perché il tasso settimanale abbia senso.
    /// L'ordine in input non conta.
    static func weightTrend(_ points: [(date: Date, kg: Double)]) -> WeightTrend? {
        let sorted = points.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        let days = last.date.timeIntervalSince(first.date) / 86_400
        guard days >= 1 else { return nil }
        let delta = last.kg - first.kg
        return WeightTrend(latestKg: last.kg, deltaKg: delta, perWeekKg: delta / days * 7)
    }
}
