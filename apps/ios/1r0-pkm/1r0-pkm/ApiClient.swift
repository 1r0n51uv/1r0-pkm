//
//  ApiClient.swift
//  1r0-pkm
//
//  Client REST minimale (URLSession) verso il backend custom (ADR-0022).
//  Auth: unico bearer statico. Non è lo strato di retry/coda — quello è
//  l'outbox in Modules/1r0-gym/Sync (ADR-0006).
//

import Foundation

struct ApiClient {
    static let shared = ApiClient()

    struct HTTPError: Error { let status: Int; let body: String }

    private func request(_ method: String, _ path: String, body: Data?) async throws -> Data {
        var req = URLRequest(url: Secrets.apiBaseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("Bearer \(Secrets.apiKey)", forHTTPHeaderField: "Authorization")
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = body
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else {
            throw HTTPError(status: code, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    func get(_ path: String) async throws -> Data {
        try await request("GET", path, body: nil)
    }

    func post(_ path: String, json: Data) async throws -> Data {
        try await request("POST", path, body: json)
    }

    func patch(_ path: String, json: Data) async throws -> Data {
        try await request("PATCH", path, body: json)
    }

    func put(_ path: String, json: Data) async throws -> Data {
        try await request("PUT", path, body: json)
    }
}
