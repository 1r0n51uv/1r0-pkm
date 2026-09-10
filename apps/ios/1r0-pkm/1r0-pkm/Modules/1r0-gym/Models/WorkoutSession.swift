//
//  WorkoutSession.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Un allenamento **importato** dal CSV Liftin' (glossario: "Workout
//  Session", ADR-0027). Read-only, identificato logicamente da
//  `(giorno, Routine)`. Niente più lifecycle `active/paused/completed`: è
//  sempre un record storico.
//

import Foundation
import SwiftData

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    /// Data dell'allenamento (colonna `Date` del CSV).
    var startedAt: Date
    /// Etichetta della scheda del giorno così com'è nel CSV (colonna
    /// `Routine`). Non è più un'entità con giorni/esercizi.
    var routineLabel: String?
    /// Durata dell'allenamento (colonna `Duration`), se disponibile.
    var durationSeconds: Int?
    /// Origine: `"liftin"` per gli import CSV.
    var source: String = "liftin"
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SetLogEntry.session)
    var sets: [SetLogEntry] = []

    init(
        id: UUID = UUID(),
        startedAt: Date,
        routineLabel: String? = nil,
        durationSeconds: Int? = nil,
        source: String = "liftin"
    ) {
        self.id = id
        self.startedAt = startedAt
        self.routineLabel = routineLabel
        self.durationSeconds = durationSeconds
        self.source = source
        self.syncedAt = nil
    }
}
