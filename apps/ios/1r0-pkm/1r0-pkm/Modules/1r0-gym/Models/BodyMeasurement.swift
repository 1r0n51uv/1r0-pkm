//
//  BodyMeasurement.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Rilevazione corporea periodica (glossario: "Body Measurement", ADR-0012):
//  peso opzionale + misure a nastro a chiavi libere. Foto rimandate
//  (niente Storage, ADR-0022).
//

import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    @Attribute(.unique) var id: UUID
    var recordedAt: Date
    var weightKg: Double?
    /// chiavi libere, es. ["waistCm": 82, "armLeftCm": 38.5]
    var measurements: [String: Double]
    var syncedAt: Date?

    init(
        id: UUID = UUID(),
        recordedAt: Date = .now,
        weightKg: Double? = nil,
        measurements: [String: Double] = [:]
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.weightKg = weightKg
        self.measurements = measurements
        self.syncedAt = nil
    }
}
