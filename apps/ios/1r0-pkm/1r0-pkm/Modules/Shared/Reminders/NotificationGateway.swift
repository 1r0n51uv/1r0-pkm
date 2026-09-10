//
//  NotificationGateway.swift
//  1r0-pkm · Modules/Shared/Reminders
//
//  Wrapper attorno a `UNUserNotificationCenter`: permessi, registrazione
//  delle categorie con azioni, e riconciliazione delle richieste pendenti
//  con quelle pianificate dalle regole. Fa anche da delegate: la risposta a
//  un'azione arriva qui anche ad app terminata — iOS rilancia il processo in
//  background per `didReceive` senza bisogno di push (ADR-0027).
//

import Foundation
import UserNotifications

/// Azioni delle notifiche azionabili. Nessuna apre l'app (`options: []`): il
/// tap va gestito in background.
enum ReminderAction {
    static let ate = "REMINDER_MEAL_ATE"       // "Sì"
    static let snooze = "REMINDER_SNOOZE"      // "Rimanda" (+30 min)
}

@MainActor
final class NotificationGateway: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    /// Chiamato per ogni risposta a una notifica di una categoria Promemoria.
    /// Impostato da `RemindersEngine`.
    var onResponse: ((UNNotificationResponse) async -> Void)?

    func becomeDelegate() { center.delegate = self }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Registra le `UNNotificationCategory` di tutte le categorie Promemoria.
    /// Solo "pasto mancante" ha azioni, per ora.
    func registerCategories() {
        let mealActions = [
            UNNotificationAction(identifier: ReminderAction.ate, title: "Sì", options: []),
            UNNotificationAction(identifier: ReminderAction.snooze, title: "Rimanda", options: []),
        ]
        var cats: Set<UNNotificationCategory> = []
        for c in ReminderCategory.allCases {
            let actions = c == .missingMeal ? mealActions : []
            cats.insert(UNNotificationCategory(identifier: c.notificationCategoryId,
                                               actions: actions,
                                               intentIdentifiers: [],
                                               options: []))
        }
        center.setNotificationCategories(cats)
    }

    /// Porta le richieste pendenti "di proprietà" delle regole a coincidere
    /// con `planned`: cancella quelle non più volute, aggiunge quelle nuove.
    /// Non tocca richieste con id fuori dai `requestPrefix` delle categorie
    /// (es. gli snooze una tantum).
    func reconcile(planned: [PlannedNotification]) async {
        let prefixes = ReminderCategory.allCases.map(\.requestPrefix)
        let pending = await center.pendingNotificationRequests()
        let owned = Set(pending.map(\.identifier).filter { id in prefixes.contains(where: id.hasPrefix) })
        let wanted = Set(planned.map(\.id))

        let toCancel = owned.subtracting(wanted)
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: Array(toCancel))
        }
        for p in planned where !owned.contains(p.id) {
            let comps = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: p.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: p.id,
                                                        content: content(for: p),
                                                        trigger: trigger))
        }
    }

    /// Ripianifica una notifica a +`delay` secondi con un id fuori dai
    /// prefissi gestiti, così `reconcile` non la cancella al giro dopo.
    func snooze(_ notification: UNNotification, by delay: TimeInterval) async {
        let req = notification.request
        let id = "snooze.\(req.identifier).\(Int(Date().timeIntervalSince1970))"
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(60, delay), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: id,
                                                    content: req.content.mutableCopy() as! UNNotificationContent,
                                                    trigger: trigger))
    }

    private func content(for p: PlannedNotification) -> UNNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = p.title
        c.body = p.body
        c.sound = .default
        c.categoryIdentifier = p.category.notificationCategoryId
        c.userInfo = p.userInfo
        return c
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])  // mostra anche in foreground
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            await self.onResponse?(response)
            completionHandler()
        }
    }
}
