//
//  WorkoutImport.swift
//  1r0-pkm · Modules/1r0-gym/Import
//
//  Applica un CSV Liftin' allo store locale (ADR-0027). "La nostra copia":
//  qui solo SwiftData; l'invio al backend (outbox + route) arriva col
//  prossimo slice.
//
//  Re-import = **merge deduplicato** su `(giorno, Routine, esercizio
//  normalizzato, Set)`: le righe già presenti si aggiornano, non si
//  duplicano.
//

import Foundation
import SwiftData

@MainActor
enum WorkoutImport {

    struct Summary: Equatable {
        var sessionsCreated = 0
        var sessionsUpdated = 0
        var setsCreated = 0
        var setsUpdated = 0
        var rowsParsed = 0

        var isEmpty: Bool {
            sessionsCreated == 0 && sessionsUpdated == 0 && setsCreated == 0 && setsUpdated == 0
        }
    }

    /// Parsa `text` e fa merge nel `context`. Rilancia gli errori di
    /// `LiftinCSV.parse`.
    @discardableResult
    static func merge(csv text: String,
                      into context: ModelContext,
                      calendar: Calendar = .current) throws -> Summary {
        let rows = try LiftinCSV.parse(text)
        var summary = Summary()
        summary.rowsParsed = rows.count

        // Tutte le sessioni esistenti in memoria (dataset piccolo).
        var sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []

        // Raggruppa le righe per (giorno, routine).
        struct Key: Hashable { let day: Date; let routine: String? }
        let groups = Dictionary(grouping: rows) { row in
            Key(day: calendar.startOfDay(for: row.date), routine: row.routine)
        }

        for (key, groupRows) in groups {
            let workoutDuration = groupRows.compactMap(\.workoutDurationSeconds).first

            let session: WorkoutSession
            if let existing = sessions.first(where: {
                calendar.isDate($0.startedAt, inSameDayAs: key.day) && $0.routineLabel == key.routine
            }) {
                session = existing
                if let d = workoutDuration, session.durationSeconds != d {
                    session.durationSeconds = d
                    session.syncedAt = nil
                    summary.sessionsUpdated += 1
                }
            } else {
                // usa la data più precisa della prima riga del gruppo per startedAt
                let startedAt = groupRows.map(\.date).min() ?? key.day
                let s = WorkoutSession(startedAt: startedAt,
                                       routineLabel: key.routine,
                                       durationSeconds: workoutDuration)
                context.insert(s)
                sessions.append(s)
                session = s
                summary.sessionsCreated += 1
            }

            for row in groupRows {
                let exKey = SetLogEntry.normalize(row.exercise)
                if let hit = session.sets.first(where: {
                    $0.exerciseKey == exKey && $0.setIndex == row.setIndex
                }) {
                    if apply(row, to: hit) {
                        hit.syncedAt = nil
                        summary.setsUpdated += 1
                    }
                } else {
                    let sl = SetLogEntry(exerciseName: row.exercise,
                                         setIndex: row.setIndex,
                                         weightKg: row.weightKg,
                                         reps: row.reps,
                                         durationSeconds: row.setDurationSeconds,
                                         isWarmup: row.isWarmup,
                                         rpe: row.perception,
                                         completedAt: session.startedAt)
                    sl.session = session   // l'inverso popola `session.sets` (no assegnazione dell'array)
                    context.insert(sl)
                    summary.setsCreated += 1
                }
            }
        }

        try context.save()
        return summary
    }

    /// Aggiorna `entry` dalla `row`; ritorna `true` se qualcosa è cambiato.
    private static func apply(_ row: LiftinCSV.Row, to entry: SetLogEntry) -> Bool {
        var changed = false
        func set<T: Equatable>(_ kp: ReferenceWritableKeyPath<SetLogEntry, T>, _ v: T) {
            if entry[keyPath: kp] != v { entry[keyPath: kp] = v; changed = true }
        }
        set(\.exerciseName, row.exercise)
        set(\.weightKg, row.weightKg)
        set(\.reps, row.reps)
        set(\.durationSeconds, row.setDurationSeconds)
        set(\.isWarmup, row.isWarmup)
        set(\.rpe, row.perception)
        return changed
    }
}
