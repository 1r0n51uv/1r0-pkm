//
//  HealthKitStatus.swift
//  1r0-pkm · Modules/Shared/HealthKit
//
//  Stato effimero (non persistito, non sincronizzato): l'ultimo problema
//  noto nel collegamento a Salute — richiesta permessi fallita, rifiutata,
//  o addirittura mai mostrata dal sistema (ADR-0037). Prima un fallimento
//  in `HealthKitService.requestAuthorization()` spariva silenziosamente
//  (`_ = await ...requestAuthorization()`, risultato scartato): l'utente
//  attivava l'interruttore "Collega Apple Salute" e non succedeva nulla di
//  visibile, senza sapere se il problema fosse suo o dell'app.
//

import Foundation

@MainActor
final class HealthKitStatus: ObservableObject {
    static let shared = HealthKitStatus()
    private init() {}

    @Published private(set) var message: String?

    func report(_ message: String) {
        self.message = message
    }

    func clear() {
        message = nil
    }
}
