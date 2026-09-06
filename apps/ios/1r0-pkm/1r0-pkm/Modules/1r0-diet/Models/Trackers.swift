//
//  Trackers.swift
//  1r0-pkm · Modules/1r0-diet
//
//  Tre tracker semplici e separati dal log pasti (ADR-0017 slice 4):
//  acqua (ml), integratori (checklist giornaliera), caffeina (voce rapida
//  dedicata). Ognuno è append-only lato eventi; lo stato "di oggi" si
//  aggrega sul client.
//

import Foundation
import SwiftData

@Model
final class WaterLog {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var amountMl: Double
    var createdAt: Date
    var syncedAt: Date?

    init(id: UUID = UUID(), loggedAt: Date = .now, amountMl: Double,
         createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.loggedAt = loggedAt
        self.amountMl = amountMl
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}

@Model
final class Supplement {
    @Attribute(.unique) var id: UUID
    var name: String
    var doseText: String?
    var scheduleText: String?
    var active: Bool = true
    var createdAt: Date
    var syncedAt: Date?

    init(id: UUID = UUID(), name: String, doseText: String? = nil,
         scheduleText: String? = nil, active: Bool = true,
         createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.doseText = doseText
        self.scheduleText = scheduleText
        self.active = active
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}

/// Una spunta "preso / non preso" per un integratore in un giorno.
@Model
final class SupplementLog {
    @Attribute(.unique) var id: UUID
    var supplementId: UUID
    var loggedAt: Date
    var taken: Bool = true
    var syncedAt: Date?

    init(id: UUID = UUID(), supplementId: UUID, loggedAt: Date = .now,
         taken: Bool = true, syncedAt: Date? = nil) {
        self.id = id
        self.supplementId = supplementId
        self.loggedAt = loggedAt
        self.taken = taken
        self.syncedAt = syncedAt
    }
}

@Model
final class CaffeineLog {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var sourceName: String
    var caffeineMg: Double
    var createdAt: Date
    var syncedAt: Date?

    init(id: UUID = UUID(), loggedAt: Date = .now, sourceName: String,
         caffeineMg: Double, createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.loggedAt = loggedAt
        self.sourceName = sourceName
        self.caffeineMg = caffeineMg
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}
