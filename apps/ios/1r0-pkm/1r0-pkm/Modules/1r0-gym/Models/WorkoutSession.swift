//
//  WorkoutSession.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Un allenamento eseguito realmente (glossario: "Workout Session").
//  status: active | paused | completed | cancelled (migration 0003).
//

import Foundation
import SwiftData

enum SessionStatus: String {
    case active, paused, completed, cancelled
}

@Model
final class WorkoutSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var statusRaw: String
    /// "app" | "watch"
    var source: String
    /// giorno di scheda da cui è partita (opzionale — sessione libera se nil)
    var routineDayId: UUID?
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SetLogEntry.session)
    var sets: [SetLogEntry] = []

    var status: SessionStatus {
        get { SessionStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    var isOpen: Bool { status == .active || status == .paused }

    init(id: UUID = UUID(), startedAt: Date = .now, source: String = "app", routineDayId: UUID? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = nil
        self.statusRaw = SessionStatus.active.rawValue
        self.source = source
        self.routineDayId = routineDayId
        self.syncedAt = nil
    }
}
