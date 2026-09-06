//
//  PhoneConnector.swift
//  1r0-pkm
//
//  WatchConnectivity: attiva la sessione all'avvio e riceve messaggi dal
//  Watch. Toolchain validata negli spike #1/#6. Non usato ancora dalla UI
//  del modulo 1r0-gym — resta come base per il log sessione da Watch
//  (ADR-0016) via lo stesso outbox del telefono (ADR-0006).
//

import Foundation
import WatchConnectivity

final class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnector()

    @Published private(set) var isActivated = false
    /// Handler per i messaggi in arrivo dal Watch; impostato da chi consuma
    /// il trasporto (es. il futuro sync sessione).
    var onMessage: (([String: Any]) -> Void)?

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.isActivated = (activationState == .activated && error == nil) }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.onMessage?(message) }
    }
}
