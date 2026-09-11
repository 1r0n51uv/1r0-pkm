//
//  ApiClient.swift
//  1r0-pkm · Modules/Shared/API
//
//  Client REST minimale (URLSession) verso il backend custom (ADR-0022).
//  Auth: unico bearer statico. Non è lo strato di retry/coda — quello è
//  l'outbox in Modules/1r0-gym/Sync (ADR-0006).
//

import Foundation

struct ApiClient {
    static let shared = ApiClient()

    struct HTTPError: Error { let status: Int; let body: String }

    /// Sotto i test UI la rete è disattivata: i `pull*` catturano l'errore e
    /// diventano no-op, così i test non dipendono dallo stato del backend.
    private static let offline = ProcessInfo.processInfo.arguments.contains("-uitest-reset")

    private func request(_ method: String, _ path: String, body: Data?) async throws -> Data {
        if Self.offline { throw HTTPError(status: -1, body: "offline (uitest)") }
        // ADR-0035 (bug fix): `appendingPathComponent` tratta l'intera stringa
        // `path` come un singolo segmento di percorso — se contiene una query
        // string (es. "v1/foods/search?q=pane") ne fa percent-escape del "?",
        // producendo un URL letteralmente "…/search%3Fq=pane" (404 lato
        // server). `URL(string:relativeTo:)` interpreta correttamente
        // path+query. Mai riprodotto dagli XCUITest: girano sempre offline
        // (`-uitest-reset`), che salta `request(...)` del tutto.
        guard let url = URL(string: path, relativeTo: Secrets.apiBaseURL) else {
            throw HTTPError(status: -1, body: "URL non valido: \(path)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(Secrets.apiKey)", forHTTPHeaderField: "Authorization")
        // ADR-0034: interruttore "database di sviluppo" in Impostazioni.
        if DBTargetPreference.isDevEnabled() {
            req.setValue("dev", forHTTPHeaderField: "X-Db-Target")
        }
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

    @discardableResult
    func delete(_ path: String) async throws -> Data {
        try await request("DELETE", path, body: nil)
    }
}
