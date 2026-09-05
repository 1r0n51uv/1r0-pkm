import Foundation
import WatchConnectivity

/// Minimal WatchConnectivity wrapper for the Watch spike (issue #1).
/// Not the final Sync/outbox architecture (ADR-0006) — just enough to
/// prove the iPhone↔Watch toolchain works before building on top of it.
final class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnector()

    @Published var lastReceivedMessage: String = "(nessun messaggio ricevuto)"
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
        guard WCSession.default.activationState == .activated else {
            statusText = "Sessione non ancora attiva"
            return
        }
        guard WCSession.default.isWatchAppInstalled else {
            statusText = "App Watch non installata"
            return
        }
        WCSession.default.sendMessage(["greeting": "Ciao dal iPhone"], replyHandler: nil) { error in
            DispatchQueue.main.async {
                self.statusText = "Errore invio: \(error.localizedDescription)"
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
        }
    }
}
