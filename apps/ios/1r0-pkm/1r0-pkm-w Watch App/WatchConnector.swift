//
//  WatchConnector.swift
//  1r0-pkm-w Watch App
//
//  Trasporto verso l'iPhone (ADR-0016: il Watch non parla mai col backend,
//  sincronizza solo via WatchConnectivity). Le mutazioni di sessione vanno
//  con `transferUserInfo` — coda FIFO, consegnata quando l'iPhone è
//  raggiungibile (resilienza se si esce dal BT range).
//

import Foundation
import WatchConnectivity

final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()

    @Published private(set) var isActivated = false
    /// numero di mutazioni ancora in coda verso l'iPhone
    @Published private(set) var pendingTransfers = 0

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Invia una mutazione di sessione all'iPhone. Se raggiungibile va subito
    /// con `sendMessage`; altrimenti (o su errore) `transferUserInfo` — coda
    /// FIFO consegnata quando l'iPhone torna attivo.
    func enqueue(_ payload: [String: Any]) {
        let s = WCSession.default
        guard s.activationState == .activated else { return }
        if s.isReachable {
            s.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                s.transferUserInfo(payload)
                self?.refreshPending()
            }
        } else {
            s.transferUserInfo(payload)
        }
        refreshPending()
    }

    private func refreshPending() {
        DispatchQueue.main.async {
            self.pendingTransfers = WCSession.default.outstandingUserInfoTransfers.count
        }
    }

    func session(_ s: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isActivated = (state == .activated && error == nil)
            self.pendingTransfers = s.outstandingUserInfoTransfers.count
        }
    }

    func session(_ s: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        DispatchQueue.main.async { self.pendingTransfers = s.outstandingUserInfoTransfers.count }
    }
}
