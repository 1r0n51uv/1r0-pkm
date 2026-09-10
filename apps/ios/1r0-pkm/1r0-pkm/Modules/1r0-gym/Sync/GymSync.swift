//
//  GymSync.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Pull di sola lettura specifici del modulo gym (ADR-0027: storico +
//  grafici). Il processore dell'outbox condiviso vive in
//  `Modules/Shared/Sync/Outbox.swift`.
//

import Foundation
import SwiftData

enum GymSync {
    /// Scarica le rilevazioni corporee e fa upsert nello store locale.
    @MainActor
    static func pullMeasurements(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/body-measurements")
            let rows = try JSONDecoder.api.decode([MeasurementDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let w = r.weight_kg.flatMap(Double.init)
                let m = r.measurements ?? [:]
                let existing = try context.fetch(
                    FetchDescriptor<BodyMeasurement>(predicate: #Predicate { $0.id == uuid })
                ).first
                if let bm = existing {
                    bm.weightKg = w
                    bm.measurements = m
                    bm.syncedAt = .now
                } else {
                    context.insert(BodyMeasurement(
                        id: uuid,
                        recordedAt: JSONDecoder.iso.date(from: r.recorded_at) ?? .now,
                        weightKg: w, measurements: m
                    ))
                    try context.fetch(FetchDescriptor<BodyMeasurement>(predicate: #Predicate { $0.id == uuid }))
                        .first?.syncedAt = .now
                }
            }
            try context.save()
        } catch {}
    }
}

struct MeasurementDTO: Decodable {
    let id: String
    let recorded_at: String
    let weight_kg: String?      // numeric → stringa
    let measurements: [String: Double]?
}
