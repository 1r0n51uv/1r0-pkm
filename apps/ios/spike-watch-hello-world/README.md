# Spike #1 — Watch↔iPhone Hello World

Vedi [issue #1](https://github.com/1r0n51uv/1r0-pkm/issues/1) e `docs/adr/0021-piano-azione-workflow.md`.
Obiettivo: validare la toolchain Swift/SwiftUI nativa (ADR-0010) prima di
costruirci sopra il modulo `1r0-gym` — nient'altro. I `*Connector.swift`
sono volutamente minimi, non lo strato Sync/outbox reale di ADR-0006.

## Dove vive il codice

A differenza di quanto previsto in origine (progetto `1r0Spike` usa-e-getta),
lo spike è implementato **dentro il progetto `1r0-pkm`** — i target Watch e
iOS reali. Deroga consapevole ad ADR-0021: finché la toolchain non è
validata, `1r0-pkm` porta il codice spike; va ripulito/sostituito quando si
implementa `1r0-gym`.

- Target iOS `1r0-pkm` (`apps/ios/1r0-pkm/1r0-pkm/`):
  - `_r0_pkmApp.swift` — crea il `PhoneConnector` nello `@main App`
  - `ContentView.swift` — bottone "Invia al Watch" + ultimo messaggio ricevuto
  - `PhoneConnector.swift` — wrapper `WCSession`
- Target `1r0-pkm-w Watch App` (`apps/ios/1r0-pkm/1r0-pkm-w Watch App/`):
  - `_r0_pkm_wApp.swift`, `ContentView.swift`, `WatchConnector.swift` — speculari

## Setup su Xcode (Mac)

1. **Elimina il target orfano** `1r0-pkm-watch` (vecchia estensione
   AppIntents, i suoi file non esistono più): progetto → TARGETS →
   `1r0-pkm-watch` → tasto destro → Delete.

2. **Target Membership**: i file sopra sono già su disco ma potrebbero non
   essere nei target. In Xcode, per ognuno controlla il pannello a destra
   "Target Membership":
   - `PhoneConnector.swift` → solo `1r0-pkm`
   - `WatchConnector.swift` → solo `1r0-pkm-w Watch App`
   - i `ContentView.swift` / `*App.swift` restano nei rispettivi target
   Se mancano dal navigator: trascinali dentro da Finder, spuntando il
   target giusto (e **solo** quello).

3. **Nessuna dipendenza esterna**: `WatchConnectivity` è un framework di
   sistema, nessun Swift Package da aggiungere.

## Test

1. Seleziona lo scheme del target iOS (`1r0-pkm`), esegui su simulatore o
   device con un Watch **accoppiato** (Watch simulator: Xcode → Window →
   Devices and Simulators; iPhone+Watch reali sono già accoppiati).
2. Esegui anche lo scheme `1r0-pkm-w Watch App` (o lascia che parta da
   solo con l'app iOS, se accoppiati).
3. Su iPhone: tocca "Invia 'Ciao' al Watch" → sul Watch appare
   "Ciao dal iPhone" e il contatore `ricevuti: N` sale a ogni invio.
4. Su Watch: tocca "Invia a iPhone" → su iPhone appare "Ciao dal Watch"
   sotto "Ultimo messaggio dal Watch", col contatore `ricevuti: N` che sale.

La sessione si attiva già all'avvio (il connector è creato nello
`@main App`, non alla prima `View`): "Sessione attiva" dovrebbe comparire
senza toccare nulla.

## Criterio di successo (issue #1)

Messaggio scambiato con successo in **entrambe le direzioni**. Se
funziona: spunta l'issue #1 su GitHub e dimmelo, così passiamo allo
spike #2 (backend) prima del TDD sul modulo `1r0-gym` (ADR-0021).

Se la sessione non si attiva (`WCSession.isSupported()` false, o
`activationState` non arriva mai a `.activated`) o i messaggi non
arrivano: il problema più comune è il Watch non accoppiato al
device/simulatore iOS in uso — verifica in Xcode → Window → Devices and
Simulators prima di sospettare un bug nel codice.
