//
//  SetLogEntry.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Una serie **importata** dal CSV Liftin' (glossario: "Set Log", ADR-0027).
//  Read-only: nessuna UI la crea o modifica; arriva solo dall'import. Una
//  serie ha `reps` **oppure** `durationSeconds` (esercizi a tempo), mai
//  entrambi.
//

import Foundation
import SwiftData

@Model
final class SetLogEntry {
    @Attribute(.unique) var id: UUID
    var session: WorkoutSession?
    /// Nome esercizio così com'è nel CSV (catalogo Liftin', misto IT/EN).
    /// Niente più `Exercise`/`exerciseId`: si raggruppa per nome normalizzato.
    var exerciseName: String
    var setIndex: Int
    var weightKg: Double
    /// `nil` per gli esercizi a tempo.
    var reps: Int?
    /// `nil` per gli esercizi a ripetizioni (colonna `Reps/Time` in `mm:ss`).
    var durationSeconds: Int?
    /// Serie di riscaldamento (colonna `Warmup`). Default in dichiarazione per
    /// la migrazione lightweight SwiftData.
    var isWarmup: Bool = false
    /// Colonna `Perception` del CSV, se numerica.
    var rpe: Double?
    /// = data della sessione (il CSV non ha un timestamp per serie).
    var completedAt: Date
    var syncedAt: Date?

    /// Chiave normalizzata per raggruppamento e dedup dell'import.
    static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
    var exerciseKey: String { Self.normalize(exerciseName) }

    init(
        id: UUID = UUID(),
        session: WorkoutSession? = nil,
        exerciseName: String,
        setIndex: Int,
        weightKg: Double,
        reps: Int? = nil,
        durationSeconds: Int? = nil,
        isWarmup: Bool = false,
        rpe: Double? = nil,
        completedAt: Date
    ) {
        self.id = id
        self.session = session
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.isWarmup = isWarmup
        self.rpe = rpe
        self.completedAt = completedAt
        self.syncedAt = nil
    }
}
