//
//  Exercise.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Un esercizio del catalogo (glossario: "Exercise"). Per ora solo `custom`
//  creati in-app; import wger/AI più avanti (ADR-0005).
//

import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroups: [String]
    var equipment: String?
    var createdAt: Date
    /// `nil` finché il backend non conferma la riga (outbox, ADR-0006).
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String] = [],
        equipment: String? = nil,
        createdAt: Date = .now,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}
