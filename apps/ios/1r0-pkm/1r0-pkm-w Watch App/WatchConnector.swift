//
//  WatchConnector.swift
//  1r0-pkm-w Watch App
//
//  Controparte watchOS di PhoneConnector. Trasporto validato (spike #1/#6);
//  il log sessione reale da Watch (ADR-0016) si costruirà su questo.
//

import Foundation
import WatchConnectivity

final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()

    @Published private(set) var isActivated = false

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Invia un messaggio all'iPhone se raggiungibile (per il log sessione).
    func send(_ payload: [String: Any]) {
        let s = WCSession.default
        guard s.activationState == .activated, s.isReachable else { return }
        s.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isActivated = (activationState == .activated && error == nil) }
    }
}
