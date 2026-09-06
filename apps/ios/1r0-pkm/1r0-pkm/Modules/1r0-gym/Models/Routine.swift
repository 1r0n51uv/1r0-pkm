//
//  Routine.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Una scheda di allenamento (glossario: "Routine"). Header + fase (ADR-0015);
//  Routine Day / Routine Exercise arrivano dopo.
//

import Foundation
import SwiftData

enum RoutinePhase: String, CaseIterable, Identifiable {
    case bulk, cut, deload, maintenance
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bulk: return "Bulk"
        case .cut: return "Cut"
        case .deload: return "Deload"
        case .maintenance: return "Mantenimento"
        }
    }
}

@Model
final class Routine {
    @Attribute(.unique) var id: UUID
    var name: String
    /// grezzo: "bulk" | "cut" | "deload" | "maintenance" | nil
    var phaseRaw: String?
    var createdAt: Date
    var syncedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \RoutineDay.routine)
    var days: [RoutineDay] = []

    var phase: RoutinePhase? {
        get { phaseRaw.flatMap(RoutinePhase.init(rawValue:)) }
        set { phaseRaw = newValue?.rawValue }
    }

    init(id: UUID = UUID(), name: String, phase: RoutinePhase? = nil,
         createdAt: Date = .now, syncedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.phaseRaw = phase?.rawValue
        self.createdAt = createdAt
        self.syncedAt = syncedAt
    }
}
