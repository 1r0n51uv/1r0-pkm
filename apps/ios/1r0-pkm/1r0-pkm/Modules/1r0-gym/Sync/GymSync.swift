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
                switch entry.kind {
                case "exercise.create":
                    let data = try await ApiClient.shared.post("v1/exercises", json: entry.payload)
                    let dto = try JSONDecoder.api.decode(ExerciseDTO.self, from: data)
                    if let uuid = UUID(uuidString: dto.id),
                       let e = try context.fetch(
                        FetchDescriptor<Exercise>(predicate: #Predicate { $0.id == uuid })
                       ).first {
                        e.syncedAt = .now
                    }
                default:
                    break
                }
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

extension JSONDecoder {
    static let api = JSONDecoder()
    static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
