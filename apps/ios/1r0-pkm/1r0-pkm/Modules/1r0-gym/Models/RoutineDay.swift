//
//  RoutineDay.swift · RoutineExercise.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Struttura di una scheda: Routine → Routine Day → Routine Exercise
//  (glossario). Il peso target non è modellato: la double progression
//  (ADR-0011) parte dal peso realmente usato.
//

import Foundation
import SwiftData

@Model
final class RoutineDay {
    @Attribute(.unique) var id: UUID
    var routine: Routine?
    var name: String
    var orderIndex: Int
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.day)
    var exercises: [RoutineExercise] = []

    init(id: UUID = UUID(), routine: Routine, name: String, orderIndex: Int = 0) {
        self.id = id
        self.routine = routine
        self.name = name
        self.orderIndex = orderIndex
        self.syncedAt = nil
    }
}

@Model
final class RoutineExercise {
    @Attribute(.unique) var id: UUID
    var day: RoutineDay?
    var exerciseId: UUID
    var exerciseName: String
    var orderIndex: Int
    var supersetGroup: String?
    var targetSets: Int
    /// range come "8-12" o "5"
    var targetReps: String
    var targetRestSeconds: Int
    var syncedAt: Date?

    var repRange: GymMath.RepRange? { GymMath.RepRange(targetReps) }

    init(
        id: UUID = UUID(),
        day: RoutineDay,
        exerciseId: UUID,
        exerciseName: String,
        orderIndex: Int = 0,
        supersetGroup: String? = nil,
        targetSets: Int = 3,
        targetReps: String = "8-12",
        targetRestSeconds: Int = 90
    ) {
        self.id = id
        self.day = day
        self.exerciseId = exerciseId
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        self.supersetGroup = supersetGroup
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetRestSeconds = targetRestSeconds
        self.syncedAt = nil
    }
}
