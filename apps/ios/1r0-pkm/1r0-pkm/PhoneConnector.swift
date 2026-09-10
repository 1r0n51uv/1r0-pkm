//
//  PhoneConnector.swift
//  1r0-pkm
//
//  WatchConnectivity lato iPhone. Attiva la sessione all'avvio; instrada i
//  messaggi e i userInfo transfer dal Watch a `onMessage`. Watch companion
//  congelato (ADR-0027): nessun consumer attivo per ora, il trasporto resta
//  come base per un futuro rilancio.
//

import Foundation
import WatchConnectivity

final class PhoneConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = PhoneConnector()

    @Published private(set) var isActivated = false
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
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { self.onMessage?(message) }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async { self.onMessage?(userInfo) }
    }
}
