//
//  SyncEngine.swift
//  1r0-pkm · Modules/Shared/Sync
//
//  Coordinatore del flush dell'outbox (ADR-0006). Fa partire il flush:
//   - quando la rete torna disponibile (`NWPathMonitor`);
//   - quando l'app torna in foreground (gestito in `_r0_pkmApp` via scenePhase);
//   - in background, via `BGAppRefreshTask` schedulata a ogni ingresso in
//     background.
//  Il retry/backoff per-entry vive in `SyncPolicy` + `Outbox.flushOutbox`.
//

import Foundation
import Network
import SwiftData
import BackgroundTasks

@MainActor
final class SyncEngine {
    static let shared = SyncEngine()
    static let bgTaskIdentifier = "dev.1r0.pkm.sync"

    private var container: ModelContainer?
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "dev.1r0.pkm.netmon")
    private var lastPathSatisfied = true
    private var started = false

    private init() {}

    /// Da chiamare una volta all'avvio dell'app col container condiviso.
    func start(container: ModelContainer) {
        guard !started else { return }
        started = true
        self.container = container

        monitor.pathUpdateHandler = { path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in SyncEngine.shared.pathChanged(satisfied: satisfied) }
        }
        monitor.start(queue: monitorQueue)

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil
        ) { task in
            let refresh = task as? BGAppRefreshTask
            Task { @MainActor in SyncEngine.shared.handleBackgroundRefresh(refresh) }
        }
    }

    /// Flush immediato (foreground). No-op se il motore non è avviato.
    func flushNow() {
        guard let context = container?.mainContext else { return }
        Task { await Outbox.flushOutbox(context) }
    }

    /// Pianifica il prossimo giro in background (≥ 15 min).
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - private

    private func pathChanged(satisfied: Bool) {
        let cameBackOnline = satisfied && !lastPathSatisfied
        lastPathSatisfied = satisfied
        if cameBackOnline { flushNow() }
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask?) {
        guard let task else { return }
        scheduleBackgroundRefresh() // concatena il giro successivo

        let work = Task { @MainActor in
            if let context = container?.mainContext {
                await Outbox.flushOutbox(context)
            }
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
