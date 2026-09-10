//
//  RemindersEngine.swift
//  1r0-pkm · Modules/Shared/Reminders
//
//  Motore dei Promemoria condiviso (ADR-0027 step 2). Speculare a
//  `SyncEngine`: `start(container:rules:)` una volta all'avvio, poi `refresh()`
//  in foreground (scenePhase) e `scheduleBackgroundRefresh()` in background
//  (`BGAppRefreshTask` `dev.1r0.pkm.reminders`).
//
//  `refresh()` valuta ogni regola abilitata sui dati già presenti e riconcilia
//  le notifiche locali pendenti col piano. Le azioni ("Sì" / "Rimanda") sono
//  gestite in background dal `NotificationGateway` che chiama `handle(_:)`.
//

import Foundation
import SwiftData
import BackgroundTasks
import UserNotifications

@MainActor
final class RemindersEngine {
    static let shared = RemindersEngine()
    static let bgTaskIdentifier = "dev.1r0.pkm.reminders"

    private let gateway = NotificationGateway()
    private var settings = ReminderSettings()
    private var container: ModelContainer?
    private var rules: [ReminderRule] = []
    private var started = false

    private init() {}

    /// Da chiamare una volta all'avvio col container condiviso e le regole
    /// registrate dai moduli.
    func start(container: ModelContainer, rules: [ReminderRule]) {
        guard !started else { return }
        started = true
        self.container = container
        self.rules = rules

        gateway.onResponse = { [weak self] response in
            await self?.handle(response)
        }
        gateway.becomeDelegate()
        gateway.registerCategories()

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.bgTaskIdentifier, using: nil
        ) { task in
            let refresh = task as? BGAppRefreshTask
            Task { @MainActor in RemindersEngine.shared.handleBackgroundRefresh(refresh) }
        }

        Task {
            await gateway.requestAuthorization()
            await runRefresh()
        }
    }

    /// Rivaluta le regole e riconcilia le notifiche pendenti. No-op se il
    /// motore non è avviato.
    func refresh() {
        guard started else { return }
        Task { await runRefresh() }
    }

    /// Pianifica il prossimo giro in background (≥ 15 min).
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.bgTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - private

    private func runRefresh() async {
        guard let context = container?.mainContext else { return }
        let now = Date()
        var planned: [PlannedNotification] = []
        for rule in rules where settings.isEnabled(rule.category) {
            planned += rule.plan(now: now, context: context)
        }
        await gateway.reconcile(planned: planned)
    }

    private func handleBackgroundRefresh(_ task: BGAppRefreshTask?) {
        guard let task else { return }
        scheduleBackgroundRefresh() // concatena il giro successivo
        let work = Task { @MainActor in
            await runRefresh()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { work.cancel() }
    }

    /// Risposta a un'azione di notifica (gestita in background, app anche
    /// terminata). Lo snooze è generico; il resto va alla regola della
    /// categoria.
    private func handle(_ response: UNNotificationResponse) async {
        let categoryId = response.notification.request.content.categoryIdentifier
        guard let category = ReminderCategory.allCases
            .first(where: { $0.notificationCategoryId == categoryId }) else { return }

        if response.actionIdentifier == ReminderAction.snooze {
            await gateway.snooze(response.notification, by: 30 * 60)
            return
        }
        guard let context = container?.mainContext,
              let rule = rules.first(where: { $0.category == category }) else { return }
        await rule.handleAction(response.actionIdentifier,
                                userInfo: response.notification.request.content.userInfo,
                                context: context)
        await runRefresh()  // lo stato può essere cambiato (es. ack) → riconcilia
    }
}
