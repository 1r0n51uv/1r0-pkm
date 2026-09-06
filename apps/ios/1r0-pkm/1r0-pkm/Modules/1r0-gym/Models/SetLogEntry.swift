//
//  SetLogEntry.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Una serie eseguita e loggata (glossario: "Set Log"). Sempre
//  modificabile/cancellabile, anche a posteriori.
//

import Foundation
import SwiftData

@Model
final class SetLogEntry {
    @Attribute(.unique) var id: UUID
    var session: WorkoutSession?
    /// riferimento all'esercizio per id (+ nome denormalizzato per la UI)
    var exerciseId: UUID
    var exerciseName: String
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rpe: Double?
    var completedAt: Date
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        session: WorkoutSession,
        exerciseId: UUID,
        exerciseName: String,
        setIndex: Int,
        weightKg: Double,
        reps: Int,
        rpe: Double? = nil,
        completedAt: Date = .now
    ) {
        self.id = id
        self.session = session
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.setIndex = setIndex
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.completedAt = completedAt
        self.syncedAt = nil
    }
}
