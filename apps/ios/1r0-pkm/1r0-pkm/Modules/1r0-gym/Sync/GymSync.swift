//
//  GymSync.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Processore dell'outbox (ADR-0006). Minimale: prova a spedire ogni
//  OutboxEntry in ordine; su successo elimina l'entry e marca il modello
//  come sincronizzato; su errore incrementa `attempts` e salva l'errore.
//  Chiamato all'avvio e dopo ogni create locale. Retry con backoff e
//  BackgroundTasks: da aggiungere quando serve.
//

import Foundation
import SwiftData

enum GymSync {
    /// Scarica il catalogo dal backend e fa upsert nello store locale.
    @MainActor
    static func pullExercises(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/exercises")
            let rows = try JSONDecoder.api.decode([ExerciseDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == uuid })
                ).first
                if let e = existing {
                    e.name = r.name
                    e.muscleGroups = r.muscle_groups
                    e.equipment = r.equipment
                    e.syncedAt = .now
                } else {
                    let e = Exercise(
                        id: uuid, name: r.name, muscleGroups: r.muscle_groups,
                        equipment: r.equipment,
                        createdAt: JSONDecoder.iso.date(from: r.created_at) ?? .now,
                        syncedAt: .now
                    )
                    context.insert(e)
                }
            }
            try context.save()
        } catch {
            // offline / backend giù: si riprova al prossimo giro. Silenzioso.
        }
    }

    /// Scarica le schede dal backend e fa upsert nello store locale.
    @MainActor
    static func pullRoutines(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/routines")
            let rows = try JSONDecoder.api.decode([RoutineDTO].self, from: data)
            for r in rows {
                guard let uuid = UUID(uuidString: r.id) else { continue }
                let existing = try context.fetch(
                    FetchDescriptor<Routine>(predicate: #Predicate { $0.id == uuid })
                ).first
                if let e = existing {
                    e.name = r.name
                    e.phaseRaw = r.phase
                    e.syncedAt = .now
                } else {
                    context.insert(Routine(
                        id: uuid, name: r.name,
                        phase: r.phase.flatMap(RoutinePhase.init(rawValue:)),
                        createdAt: JSONDecoder.iso.date(from: r.created_at) ?? .now,
                        syncedAt: .now
                    ))
                }
            }
            try context.save()
        } catch {}
    }

    /// Scarica la config piastre e fa upsert nella riga singleton locale.
    @MainActor
    static func pullPlateConfig(into context: ModelContext) async {
        do {
            let data = try await ApiClient.shared.get("v1/plate-config")
            let dto = try JSONDecoder.api.decode(PlateConfigDTO.self, from: data)
            let bar = Double(dto.bar_weight_kg) ?? 20
            let plates = dto.available_plates_kg.sorted()
            let existing = try context.fetch(FetchDescriptor<PlateConfig>()).first
            if let cfg = existing {
                cfg.barWeightKg = bar
                cfg.availablePlatesKg = plates
                cfg.syncedAt = .now
            } else {
                let cfg = PlateConfig(barWeightKg: bar, availablePlatesKg: plates)
                cfg.syncedAt = .now
                context.insert(cfg)
            }
            try context.save()
        } catch {}
    }

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

    /// Svuota l'outbox spedendo ogni entry.
    @MainActor
    static func flushOutbox(_ context: ModelContext) async {
        let pending: [OutboxEntry]
        do {
            pending = try context.fetch(
                FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.createdAt)])
            )
        } catch { return }

        for entry in pending {
            do {
                let backendId = try await send(entry)
                markSynced(kind: entry.kind, id: backendId, in: context)
                context.delete(entry)
                try context.save()
            } catch {
                entry.attempts += 1
                entry.lastError = String(describing: error)
                try? context.save()
                // ferma il flush: mantiene l'ordine, riprova più tardi
                return
            }
        }
    }

    private struct IdOnly: Decodable { let id: String }

    /// Spedisce un'entry e ritorna l'id della riga backend (o "" se non ha id).
    private static func send(_ entry: OutboxEntry) async throws -> String {
        let api = ApiClient.shared
        func id(_ data: Data) throws -> String {
            try JSONDecoder.api.decode(IdOnly.self, from: data).id
        }
        switch entry.kind {
        case "exercise.create":
            return try id(await api.post("v1/exercises", json: entry.payload))
        case "routine.create":
            return try id(await api.post("v1/routines", json: entry.payload))
        case "session.create":
            return try id(await api.post("v1/workout-sessions", json: entry.payload))
        case "session.update":
            let sid = try JSONDecoder.api.decode(IdOnly.self, from: entry.payload).id
            return try id(await api.patch("v1/workout-sessions/\(sid)", json: entry.payload))
        case "setlog.create":
            return try id(await api.post("v1/set-logs", json: entry.payload))
        case "measurement.create":
            return try id(await api.post("v1/body-measurements", json: entry.payload))
        case "plateconfig.put":
            _ = try await api.put("v1/plate-config", json: entry.payload)
            return ""
        default:
            throw ApiClient.HTTPError(status: -1, body: "kind sconosciuto: \(entry.kind)")
        }
    }

    @MainActor
    private static func markSynced(kind: String, id: String, in context: ModelContext) {
        if kind == "plateconfig.put" {
            try? context.fetch(FetchDescriptor<PlateConfig>()).first?.syncedAt = .now
            return
        }
        guard let uuid = UUID(uuidString: id) else { return }
        switch kind {
        case "exercise.create":
            try? context.fetch(FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "routine.create":
            try? context.fetch(FetchDescriptor<Routine>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "session.create", "session.update":
            try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "setlog.create":
            try? context.fetch(FetchDescriptor<SetLogEntry>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "measurement.create":
            try? context.fetch(FetchDescriptor<BodyMeasurement>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        default:
            break
        }
    }
}

// MARK: - wire

struct ExerciseDTO: Decodable {
    let id: String
    let name: String
    let source: String
    let muscle_groups: [String]
    let equipment: String?
    let created_at: String
}

struct RoutineDTO: Decodable {
    let id: String
    let name: String
    let phase: String?
    let created_at: String
}

struct PlateConfigDTO: Decodable {
    let bar_weight_kg: String   // numeric arriva come stringa da pg
    let available_plates_kg: [Double]
}

struct MeasurementDTO: Decodable {
    let id: String
    let recorded_at: String
    let weight_kg: String?      // numeric → stringa
    let measurements: [String: Double]?
}

extension JSONDecoder {
    static let api = JSONDecoder()
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
