//
//  SyncPolicy.swift
//  1r0-pkm · Modules/1r0-gym
//
//  Regole pure per l'outbox (ADR-0006): quanto aspettare prima di riprovare
//  una entry fallita, e se un errore è transitorio (riprova) o permanente
//  (entry "poison" — non riproverà mai da sola, va messa da parte così non
//  blocca la coda in ordine).
//

import Foundation

enum SyncPolicy {
    /// Esito della classificazione di un errore di invio.
    enum Retryability: Equatable {
        /// Errore transitorio (rete assente, backend giù, 5xx, 429, timeout):
        /// riprova con backoff.
        case transient
        /// Errore permanente lato client (400/422/404/…): la richiesta non
        /// avrà mai successo così com'è — marca l'entry come fallita e vai
        /// avanti con le altre.
        case permanent
    }

    /// Tetto massimo del backoff: oltre questo non ha senso aspettare di più.
    static let maxBackoff: TimeInterval = 3600 // 1h

    /// Ritardo prima del tentativo n. `attempts` (0 = mai provata → subito).
    /// Exponential backoff con base 5s: 0, 5, 10, 20, 40, 80, … fino a `maxBackoff`.
    static func backoffDelay(attempts: Int) -> TimeInterval {
        guard attempts > 0 else { return 0 }
        let capped = min(attempts, 20) // evita overflow di `pow`
        let delay = 5.0 * pow(2.0, Double(capped - 1))
        return min(delay, maxBackoff)
    }

    /// Istante del prossimo tentativo dato l'ultimo errore.
    static func nextAttempt(after date: Date, attempts: Int) -> Date {
        date.addingTimeInterval(backoffDelay(attempts: attempts))
    }

    /// Classifica un codice di stato HTTP (o `-1` per errore di trasporto).
    static func classify(status: Int) -> Retryability {
        switch status {
        case 408, 425, 429:            return .transient   // timeout / too early / rate limit
        case 500...599:                return .transient   // backend in errore o in deploy
        case ..<0, 0:                  return .transient   // nessuna rete / trasporto fallito
        case 409:                      return .transient   // conflitto d'ordine: si risolve quando arriva la dipendenza
        case 401, 403:                 return .permanent   // auth rotta: inutile martellare
        case 400...499:                return .permanent   // richiesta malformata / risorsa assente
        default:                       return .transient
        }
    }

    /// Numero di tentativi oltre il quale una entry ancora "transient" viene
    /// comunque parcheggiata come fallita (per non riprovare all'infinito una
    /// entry che il backend continua a rifiutare con 5xx).
    static let maxTransientAttempts = 12
}
