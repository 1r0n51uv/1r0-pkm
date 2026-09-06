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
                    e.source = r.source
                    e.externalId = r.external_id
                    e.instructions = r.instructions
                    e.videoURL = r.video_url
                    e.imageURL = r.image_url
                    e.syncedAt = .now
                } else {
                    let e = Exercise(
                        id: uuid, name: r.name, muscleGroups: r.muscle_groups,
                        equipment: r.equipment, source: r.source, externalId: r.external_id,
                        instructions: r.instructions, videoURL: r.video_url, imageURL: r.image_url,
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

    /// Import una tantum del catalogo wger lato backend, poi ripull locale
    /// (ADR-0005). Ritorna il conteggio, o `nil` se la chiamata fallisce.
    struct WgerSyncResult: Decodable { let inserted: Int; let updated: Int; let skipped: Int }

    @MainActor
    @discardableResult
    static func wgerSync(into context: ModelContext) async -> WgerSyncResult? {
        do {
            let body = try JSONSerialization.data(withJSONObject: ["max": 1000])
            let data = try await ApiClient.shared.post("v1/exercises/wger-sync", json: body)
            let res = try JSONDecoder.api.decode(WgerSyncResult.self, from: data)
            await pullExercises(into: context)
            return res
        } catch {
            return nil
        }
    }

    /// Proposta strutturata di Claude per un esercizio non a catalogo (ADR-0005).
    struct AiExerciseProposal: Decodable {
        let name: String
        let muscleGroups: [String]
        let equipment: String?
        let instructions: String?
    }

    enum AiImportError: Error { case notConfigured, failed }

    /// Chiede a Claude (via backend) i dati di un esercizio. NON salva niente:
    /// la conferma/modifica dell'utente avviene nella UI prima del POST.
    static func aiImport(query: String) async -> Result<AiExerciseProposal, AiImportError> {
        do {
            let body = try JSONSerialization.data(withJSONObject: ["query": query])
            let data = try await ApiClient.shared.post("v1/exercises/ai-import", json: body)
            let p = try JSONDecoder.api.decode(AiExerciseProposal.self, from: data)
            return .success(p)
        } catch let e as ApiClient.HTTPError where e.status == 500 {
            return .failure(.notConfigured) // ANTHROPIC_API_KEY assente
        } catch {
            return .failure(.failed)
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

    /// Scarica l'albero di una scheda (giorni + esercizi) e fa upsert.
    @MainActor
    static func pullRoutineTree(routineId: UUID, into context: ModelContext) async {
        guard let routine = try? context.fetch(
            FetchDescriptor<Routine>(predicate: #Predicate { $0.id == routineId })
        ).first else { return }
        do {
            let data = try await ApiClient.shared.get("v1/routines/\(routineId.uuidString)/tree")
            let tree = try JSONDecoder.api.decode(RoutineTreeDTO.self, from: data)
            for d in tree.days {
                guard let dayId = UUID(uuidString: d.id) else { continue }
                let day: RoutineDay
                if let existing = try context.fetch(
                    FetchDescriptor<RoutineDay>(predicate: #Predicate { $0.id == dayId })
                ).first {
                    existing.name = d.name
                    existing.orderIndex = d.order_index
                    existing.syncedAt = .now
                    day = existing
                } else {
                    day = RoutineDay(id: dayId, routine: routine, name: d.name, orderIndex: d.order_index)
                    day.syncedAt = .now
                    context.insert(day)
                }
                for x in d.exercises {
                    guard let xid = UUID(uuidString: x.id),
                          let exId = UUID(uuidString: x.exercise_id) else { continue }
                    if let existing = try context.fetch(
                        FetchDescriptor<RoutineExercise>(predicate: #Predicate { $0.id == xid })
                    ).first {
                        existing.orderIndex = x.order_index
                        existing.supersetGroup = x.superset_group
                        existing.targetSets = x.target_sets
                        existing.targetReps = x.target_reps
                        existing.targetRestSeconds = x.target_rest_seconds
                        existing.exerciseName = x.exercise_name
                        existing.syncedAt = .now
                    } else {
                        let re = RoutineExercise(
                            id: xid, day: day, exerciseId: exId, exerciseName: x.exercise_name,
                            orderIndex: x.order_index, supersetGroup: x.superset_group,
                            targetSets: x.target_sets, targetReps: x.target_reps,
                            targetRestSeconds: x.target_rest_seconds
                        )
                        re.syncedAt = .now
                        context.insert(re)
                    }
                }
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

    /// Svuota l'outbox spedendo ogni entry in ordine (ADR-0006).
    ///
    /// - salta le entry già parcheggiate (`failedPermanently`);
    /// - rispetta il backoff: se la testa della coda non è ancora "matura"
    ///   si ferma, per non rompere l'ordine FIFO (un `setlog.create` non deve
    ///   partire prima del suo `session.create`);
    /// - un 4xx marca l'entry come fallita permanentemente e passa oltre,
    ///   così una entry "poison" non blocca per sempre le successive.
    @MainActor
    static func flushOutbox(_ context: ModelContext) async {
        let pending: [OutboxEntry]
        do {
            pending = try context.fetch(
                FetchDescriptor<OutboxEntry>(sortBy: [SortDescriptor(\.createdAt)])
            )
        } catch { return }

        let now = Date()
        for entry in pending where !entry.failedPermanently {
            if let next = entry.nextAttemptAt, next > now {
                // testa della coda non ancora matura → riprova più tardi
                return
            }
            do {
                let backendId = try await send(entry)
                markSynced(kind: entry.kind, id: backendId, in: context)
                context.delete(entry)
                try context.save()
            } catch {
                entry.attempts += 1
                entry.lastError = String(describing: error)

                let status = (error as? ApiClient.HTTPError)?.status ?? -1
                let verdict = (error is ApiClient.HTTPError)
                    ? SyncPolicy.classify(status: status)
                    : .permanent // errore di serializzazione/logica: non migliorerà

                switch verdict {
                case .permanent:
                    entry.failedPermanently = true
                    entry.nextAttemptAt = nil
                    try? context.save()
                    continue // parcheggiata: prova comunque le successive
                case .transient:
                    if entry.attempts >= SyncPolicy.maxTransientAttempts {
                        entry.failedPermanently = true
                        entry.nextAttemptAt = nil
                        try? context.save()
                        continue
                    }
                    entry.nextAttemptAt = SyncPolicy.nextAttempt(after: now, attempts: entry.attempts)
                    try? context.save()
                    return // mantiene l'ordine, riprova dopo il backoff
                }
            }
        }
    }

    /// Rimette in coda tutte le entry parcheggiate (l'utente ha toccato
    /// "riprova") e rilancia il flush.
    @MainActor
    static func retryFailed(_ context: ModelContext) async {
        let stuck = (try? context.fetch(FetchDescriptor<OutboxEntry>(
            predicate: #Predicate { $0.failedPermanently }
        ))) ?? []
        for e in stuck {
            e.failedPermanently = false
            e.nextAttemptAt = nil
            e.attempts = 0
            e.lastError = nil
        }
        try? context.save()
        await flushOutbox(context)
    }

    /// Conteggio entry in coda (in attesa o parcheggiate) — per la UI.
    @MainActor
    static func outboxCounts(_ context: ModelContext) -> (pending: Int, failed: Int) {
        let all = (try? context.fetch(FetchDescriptor<OutboxEntry>())) ?? []
        let failed = all.filter(\.failedPermanently).count
        return (all.count - failed, failed)
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
        case "routineday.create":
            return try id(await api.post("v1/routine-days", json: entry.payload))
        case "routineexercise.create":
            return try id(await api.post("v1/routine-exercises", json: entry.payload))
        case "plateconfig.put":
            _ = try await api.put("v1/plate-config", json: entry.payload)
            return ""
        case "food.create":
            return try id(await api.post("v1/foods", json: entry.payload))
        case "mealentry.create":
            return try id(await api.post("v1/meal-entries", json: entry.payload))
        case "nutritiongoal.create":
            return try id(await api.post("v1/nutrition-goals", json: entry.payload))
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
        case "routineday.create":
            try? context.fetch(FetchDescriptor<RoutineDay>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "routineexercise.create":
            try? context.fetch(FetchDescriptor<RoutineExercise>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "food.create":
            try? context.fetch(FetchDescriptor<Food>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "mealentry.create":
            try? context.fetch(FetchDescriptor<MealEntry>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "nutritiongoal.create":
            try? context.fetch(FetchDescriptor<NutritionGoal>(predicate: #Predicate { $0.id == uuid }))
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
    let external_id: String?
    let muscle_groups: [String]
    let equipment: String?
    let instructions: String?
    let video_url: String?
    let image_url: String?
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

struct RoutineTreeDTO: Decodable {
    struct Day: Decodable {
        let id: String
        let name: String
        let order_index: Int
        let exercises: [Ex]
    }
    struct Ex: Decodable {
        let id: String
        let exercise_id: String
        let exercise_name: String
        let order_index: Int
        let superset_group: String?
        let target_sets: Int
        let target_reps: String
        let target_rest_seconds: Int
    }
    let id: String
    let days: [Day]
}

extension JSONDecoder {
    static let api = JSONDecoder()
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
