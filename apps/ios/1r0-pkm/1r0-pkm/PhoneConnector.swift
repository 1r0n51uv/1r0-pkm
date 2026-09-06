//
//  PhoneConnector.swift
//  1r0-pkm
//
//  Created by 1r0n51uv on 05/09/26.
//

import Foundation
import WatchConnectivity

/// Minimal WatchConnectivity wrapper for the Watch spike (issue #1).
/// Not the final Sync/outbox architecture (ADR-0006) — just enough to
/// prove the iPhone↔Watch toolchain works before building on top of it.
final class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnector()

    @Published var lastReceivedMessage: String = "(nessun messaggio ricevuto)"
    @Published var receivedCount: Int = 0
    @Published var statusText: String = "Attivazione in corso..."

    private override init() {
        super.init()
        guard WCSession.isSupported() else {
            statusText = "WatchConnectivity non supportato su questo device"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendHelloToWatch() {
        let session = WCSession.default
        guard session.activationState == .activated else {
            statusText = "Sessione non ancora attiva"
            return
        }
        guard session.isWatchAppInstalled else {
            statusText = "App Watch non installata"
            return
        }
        guard session.isReachable else {
            statusText = "Watch non raggiungibile (fuori portata o app Watch non in foreground)"
            return
        }
        session.sendMessage(["greeting": "Ciao dal iPhone"], replyHandler: nil) { [weak self] error in
            DispatchQueue.main.async {
                self?.statusText = "Errore invio: \(error.localizedDescription)"
            }
        }
        statusText = "Messaggio inviato"
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.statusText = error != nil ? "Errore attivazione: \(error!.localizedDescription)" : "Sessione attiva"
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = message["greeting"] as? String ?? "messaggio senza testo"
            self.receivedCount += 1
        }
    }
}
