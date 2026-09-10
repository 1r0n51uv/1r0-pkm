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
        case "session.create":
            return try id(await api.post("v1/workout-sessions", json: entry.payload))
        case "session.update":
            let sid = try JSONDecoder.api.decode(IdOnly.self, from: entry.payload).id
            return try id(await api.patch("v1/workout-sessions/\(sid)", json: entry.payload))
        case "setlog.create":
            return try id(await api.post("v1/set-logs", json: entry.payload))
        case "measurement.create":
            return try id(await api.post("v1/body-measurements", json: entry.payload))
        case "food.create":
            return try id(await api.post("v1/foods", json: entry.payload))
        case "mealentry.create":
            return try id(await api.post("v1/meal-entries", json: entry.payload))
        case "nutritiongoal.create":
            return try id(await api.post("v1/nutrition-goals", json: entry.payload))
        case "recipe.create":
            return try id(await api.post("v1/recipes", json: entry.payload))
        case "plannedmeal.create":
            return try id(await api.post("v1/planned-meals", json: entry.payload))
        case "shoppingitem.put":
            return try id(await api.post("v1/shopping-list", json: entry.payload))
        case "waterlog.create":
            return try id(await api.post("v1/water-logs", json: entry.payload))
        case "supplement.put":
            return try id(await api.post("v1/supplements", json: entry.payload))
        case "supplementlog.put":
            return try id(await api.post("v1/supplement-logs", json: entry.payload))
        case "caffeinelog.create":
            return try id(await api.post("v1/caffeine-logs", json: entry.payload))
        default:
            throw ApiClient.HTTPError(status: -1, body: "kind sconosciuto: \(entry.kind)")
        }
    }

    @MainActor
    private static func markSynced(kind: String, id: String, in context: ModelContext) {
        guard let uuid = UUID(uuidString: id) else { return }
        switch kind {
        case "session.create", "session.update":
            try? context.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "setlog.create":
            try? context.fetch(FetchDescriptor<SetLogEntry>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "measurement.create":
            try? context.fetch(FetchDescriptor<BodyMeasurement>(predicate: #Predicate { $0.id == uuid }))
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
        case "recipe.create":
            try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "plannedmeal.create":
            try? context.fetch(FetchDescriptor<PlannedMeal>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "shoppingitem.put":
            try? context.fetch(FetchDescriptor<ShoppingListItem>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "waterlog.create":
            try? context.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "supplement.put":
            try? context.fetch(FetchDescriptor<Supplement>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "supplementlog.put":
            try? context.fetch(FetchDescriptor<SupplementLog>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        case "caffeinelog.create":
            try? context.fetch(FetchDescriptor<CaffeineLog>(predicate: #Predicate { $0.id == uuid }))
                .first?.syncedAt = .now
        default:
            break
        }
    }
}

// MARK: - wire

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
