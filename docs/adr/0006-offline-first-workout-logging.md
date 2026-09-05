# ADR-0006: Offline-first per il log allenamento

## Status
Accettata — rivista dopo [ADR-0010](0010-swift-native-ios-watch.md) (Swift nativo invece di Expo) e confermata da [ADR-0016](0016-watch-app-scope.md) (log completo autonomo dal Watch, iPhone resta l'unico hub verso Supabase).

## Contesto
In palestra spesso non c'è rete. Il log di una Workout Session (Set Log) deve funzionare comunque e sincronizzarsi quando torna la connessione. Il backend (Supabase self-hosted su AWS, vedi ADR-0009) potrebbe anche non essere raggiungibile per motivi di rete lato client, non solo per assenza di segnale in palestra.

## Decisione
- **SwiftData** come sorgente di verità immediata per `Routine`, `Workout Session` e `Set Log` sul device (iPhone e, per la sessione attiva, anche Watch).
- Sync verso Supabase (self-hosted) con un outbox pattern: ogni mutazione locale genera un record di sync in coda, processato da un `BackgroundTask` quando la rete torna disponibile.
- Conflitti risolti "last write wins" su `updatedAt`, accettabile per un solo utente reale multi-device (non c'è concorrenza vera tra scritture simultanee).
- Il Watch logga in SwiftData locale sul Watch stesso durante l'allenamento (nessuna dipendenza dalla rete Watch, spesso assente in palestra) e sincronizza con l'iPhone via `WatchConnectivity` non appena raggiungibile; l'iPhone resta l'hub verso Supabase — il Watch non parla mai direttamente col backend nell'MVP.
- Routine/Exercise (dati meno volatili) restano cache-then-network senza outbox dedicato.

## Conseguenze
- Introduce uno strato di sync client-side non banale (outbox + retry, gestito con `BackgroundTasks`/`URLSession` background) da costruire prima di poter dire "il modulo `1r0-gym` è affidabile".
- Essendo il backend self-hosted (non gestito), un downtime dell'istanza AWS si comporta esattamente come "nessuna rete" lato client — l'outbox deve già gestire bene questo caso, quindi nessuna logica aggiuntiva richiesta per l'assenza di backup automatico (ADR-0009).
