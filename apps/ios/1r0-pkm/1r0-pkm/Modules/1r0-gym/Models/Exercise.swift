//
//  Exercise.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Un esercizio del catalogo (glossario: "Exercise"). Tre fonti (ADR-0005):
//  `custom` creato a mano, `wger` importato dal database pubblico, `ai`
//  proposto da Claude e confermato dall'utente.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroups: [String]
    var equipment: String?
    /// "custom" | "wger" | "ai" (ADR-0005). La UI mostra la fonte.
    /// Default nella dichiarazione: serve alla migrazione lightweight SwiftData
    /// per le righe già su disco (senza, `ModelContainer(for:)` fallisce e
    /// l'app non parte).
    var source: String = "custom"
    /// id/uuid nella fonte esterna (wger), per re-sync. `nil` per custom/ai.
    var externalId: String?
    var instructions: String?
    var videoURL: String?
    var imageURL: String?
    var createdAt: Date
    /// `nil` finché il backend non conferma la riga (outbox, ADR-0006).
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroups: [String] = [],
        equipment: String? = nil,
        source: String = "custom",
        externalId: String? = nil,
        instructions: String? = nil,
        videoURL: String? = nil,
        imageURL: String? = nil,
        createdAt: Date = .now,
        syncedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.source = source
        self.externalId = externalId
        self.instructions = instructions
        self.videoURL = videoURL
        self.imageURL = imageURL
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}
