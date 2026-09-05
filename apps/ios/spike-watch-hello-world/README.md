# Spike #1 — Watch↔iPhone Hello World

Vedi [issue #1](https://github.com/1r0n51uv/1r0-pkm/issues/1) e `docs/adr/0021-piano-azione-workflow.md`.
Obiettivo: validare la toolchain Swift/SwiftUI nativa (ADR-0010) prima di
costruirci sopra il modulo `1r0-gym` — nient'altro. Non è architettura
definitiva: i file `*Connector.swift` qui dentro sono volutamente minimi
e duplicati tra i due target, non lo strato Sync/outbox reale di ADR-0006.

I file Swift in questa cartella **non sono dentro un progetto Xcode** —
un `.xcodeproj`/`.xcworkspace` è binario/generato da Xcode, non ha senso
scriverlo a mano da qui (stesso motivo per cui `apps/ios/README.md` non
lo include). Vanno creati e incollati in un progetto Xcode sul tuo Mac.

## Setup su Xcode (Mac)

1. **Crea il progetto**: Xcode → New Project → **App**, interfaccia
   SwiftUI, nome `1r0Spike` (o come preferisci — è uno spike, non l'app
   finale), bundle id es. `dev.1r0.spike`. Salvalo pure fuori da questo
   repo, o dentro `apps/ios/` se preferisci tenerlo tracciato: **non è
   però necessario committare il progetto Xcode stesso**, solo il
   risultato del test in `docs/adr/0021` (spunta l'issue).

2. **Aggiungi il target Watch**: File → New → Target → **Watch App**,
   associato all'app iOS appena creata, stesso prefisso bundle id
   (es. `dev.1r0.spike.watchkitapp`).

3. **Sostituisci i file generati** nel target iOS con quelli in
   `apps/ios/spike-watch-hello-world/iOS/`:
   - `OneRoSpikeApp.swift` (sostituisce il file `@main App` generato)
   - `ContentView.swift`
   - `PhoneConnector.swift` (nuovo file, aggiungilo al target iOS)

4. **Sostituisci i file generati** nel target Watch con quelli in
   `apps/ios/spike-watch-hello-world/Watch/`:
   - `OneRoSpikeWatchApp.swift`
   - `WatchContentView.swift`
   - `WatchConnector.swift` (nuovo file, aggiungilo al target Watch —
     **non** al target iOS: ogni file va assegnato al target giusto
     nel pannello "Target Membership" a destra in Xcode)

5. **Nessuna dipendenza esterna**: `WatchConnectivity` è un framework
   di sistema, nessun Swift Package da aggiungere.

## Test

1. Seleziona lo scheme del target iOS, esegui su simulatore o device
   con un Watch **accoppiato al simulatore/device** (Watch simulator si
   accoppia da Xcode → Window → Devices and Simulators, o è già
   accoppiato di default se usi un iPhone+Watch reali).
2. Esegui anche lo scheme del target Watch (o lascia che si avvii da
   solo insieme all'app iOS, se accoppiati).
3. Su iPhone: tocca "Invia 'Ciao' al Watch" → sul Watch deve apparire
   "Ciao dal iPhone" nel testo in alto e il contatore `ricevuti: N`
   che aumenta a ogni invio.
4. Su Watch: tocca "Invia a iPhone" → su iPhone deve apparire
   "Ciao dal Watch" sotto "Ultimo messaggio dal Watch", di nuovo col
   contatore `ricevuti: N` che sale.

La sessione si attiva già all'avvio dell'app (il connector è creato
nello `@main App`, non alla prima `View`): "Sessione attiva" dovrebbe
comparire senza toccare nulla.

## Criterio di successo (issue #1)

Messaggio scambiato con successo in **entrambe le direzioni**. Se
funziona: spunta l'issue #1 su GitHub e dimmelo, così passiamo allo
spike #2 (backend) prima del TDD sul modulo `1r0-gym` (ADR-0021).

Se qualcosa non attiva la sessione (`WCSession.isSupported()` false, o
`activationState` non arriva mai a `.activated`) o i messaggi non
arrivano: il problema più comune è il Watch non accoppiato al
device/simulatore iOS che stai usando — verifica in Xcode → Window →
Devices and Simulators prima di sospettare un bug nel codice.
