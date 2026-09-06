//
//  ApiClient.swift
//  1r0-pkm
//
//  Created by 1r0n51uv on 05/09/26.
//

import Foundation

/// Minimal URLSession client for the end-to-end spike (issue #6). Not the
/// real Sync/outbox layer (ADR-0006) — one POST, no retry, no queue.
struct ApiClient {
    static let shared = ApiClient()

    struct SetLogResult: Decodable {
        let id: String
        let setIndex: Int
        let workoutSessionId: String

        enum CodingKeys: String, CodingKey {
            case id
            case setIndex = "set_index"
            case workoutSessionId = "workout_session_id"
        }
    }

    /// POST /v1/set-logs — returns a short human summary for the UI.
    func postSetLog(weightKg: Double, reps: Int) async -> String {
        var req = URLRequest(url: Secrets.apiBaseURL.appendingPathComponent("v1/set-logs"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(Secrets.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["weightKg": weightKg, "reps": reps])

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            guard code == 201 else {
                let body = String(data: data, encoding: .utf8) ?? ""
                return "backend \(code): \(body)"
            }
            let r = try JSONDecoder().decode(SetLogResult.self, from: data)
            return "salvato · set #\(r.setIndex) · id \(r.id.prefix(8))… · sess \(r.workoutSessionId.prefix(8))…"
        } catch {
            return "errore rete: \(error.localizedDescription)"
        }
    }
}
