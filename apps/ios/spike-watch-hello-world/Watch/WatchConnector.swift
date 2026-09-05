import Foundation
import WatchConnectivity

/// Watch-side counterpart of PhoneConnector.swift (iOS target).
/// Minimal WatchConnectivity wrapper for the Watch spike (issue #1).
final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()

    @Published var lastReceivedMessage: String = "(nessun messaggio ricevuto)"
    @Published var receivedCount: Int = 0
    @Published var statusText: String = "Attivazione in corso..."

    private override init() {
        super.init()
        guard WCSession.isSupported() else {
            statusText = "WatchConnectivity non supportato"
            return
        }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func sendHelloToPhone() {
        let session = WCSession.default
        guard session.activationState == .activated else {
            statusText = "Sessione non ancora attiva"
            return
        }
        guard session.isReachable else {
            statusText = "iPhone non raggiungibile"
            return
        }
        session.sendMessage(["greeting": "Ciao dal Watch"], replyHandler: nil) { [weak self] error in
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

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            self.lastReceivedMessage = message["greeting"] as? String ?? "messaggio senza testo"
            self.receivedCount += 1
        }
    }
}
