//
//  GymStats.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Aggregazioni pure sopra le sessioni importate (ADR-0027 step 3), per la
//  vista storico + grafici. Riusa `GymMath` (Epley 1RM, volume). Ignora le
//  serie di riscaldamento, quelle a 0 kg e quelle a tempo (senza `reps`).
//

import Foundation

enum GymStats {

    /// Serie eleggibili per 1RM / volume: non warmup, peso > 0, `reps` presenti.
    static func workingSets(_ sets: [SetLogEntry]) -> [(weightKg: Double, reps: Int)] {
        sets.compactMap { s in
            guard !s.isWarmup, s.weightKg > 0, let r = s.reps, r > 0 else { return nil }
            return (weightKg: s.weightKg, reps: r)
        }
    }

    /// Nomi esercizio distinti (per chiave normalizzata), ordinati per numero
    /// di serie decrescente; il nome mostrato è la prima occorrenza incontrata.
    static func exercises(in sessions: [WorkoutSession]) -> [String] {
        var count: [String: Int] = [:]
        var display: [String: String] = [:]
        for session in sessions {
            for set in session.sets {
                count[set.exerciseKey, default: 0] += 1
                if display[set.exerciseKey] == nil { display[set.exerciseKey] = set.exerciseName }
            }
        }
        return count
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .compactMap { display[$0.key] }
    }

    struct Point: Equatable {
        let date: Date
        let value: Double
    }

    /// Miglior 1RM stimato per sessione per l'esercizio dato, in ordine
    /// cronologico. Sessioni senza serie di lavoro per quell'esercizio: escluse.
    static func oneRMSeries(_ sessions: [WorkoutSession], exercise name: String) -> [Point] {
        series(sessions, exercise: name) { GymMath.bestEstimated1RM($0) }
    }

    /// Volume totale (Σ peso × reps) per sessione per l'esercizio dato.
    static func volumeSeries(_ sessions: [WorkoutSession], exercise name: String) -> [Point] {
        series(sessions, exercise: name) { GymMath.volume($0) }
    }

    private static func series(
        _ sessions: [WorkoutSession],
        exercise name: String,
        _ aggregate: ([(weightKg: Double, reps: Int)]) -> Double
    ) -> [Point] {
        let key = SetLogEntry.normalize(name)
        return sessions
            .compactMap { session -> Point? in
                let ws = workingSets(session.sets.filter { $0.exerciseKey == key })
                guard !ws.isEmpty else { return nil }
                let v = aggregate(ws)
                return v > 0 ? Point(date: session.startedAt, value: v) : nil
            }
            .sorted { $0.date < $1.date }
    }
}
