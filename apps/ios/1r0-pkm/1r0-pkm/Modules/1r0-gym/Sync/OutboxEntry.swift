//
//  OutboxEntry.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Coda locale (SwiftData) di mutazioni non ancora sincronizzate col backend
//  (ADR-0006). Ogni scrittura locale accoda un OutboxEntry; GymSync lo
//  riprocessa (all'avvio, dopo ogni create, quando torna la rete).
//

import Foundation
import SwiftData

@Model
final class OutboxEntry {
    @Attribute(.unique) var id: UUID
    /// es. "exercise.create"
    var kind: String
    /// corpo JSON già serializzato della richiesta
    var payload: Data
    var createdAt: Date
    var attempts: Int
    var lastError: String?

    init(id: UUID = UUID(), kind: String, payload: Data, createdAt: Date = .now) {
        self.id = id
        self.kind = kind
        self.payload = payload
        self.createdAt = createdAt
        self.attempts = 0
        self.lastError = nil
    }
}
