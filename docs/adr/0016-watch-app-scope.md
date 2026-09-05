# ADR-0016: Scope dell'app Watch

## Status
Accettata

## Contesto
ADR-0010 stabilisce che l'app Watch è nativa (SwiftUI, non un bridge Expo), ADR-0006 che l'iPhone resta l'hub verso Supabase. Restava da definire cosa l'app Watch fa concretamente durante un allenamento.

## Decisione

### Logging
- **Log completo autonomo dal Watch**: l'utente vede la routine del giorno, scorre gli esercizi e logga peso/reps di ogni serie senza bisogno del telefono in mano. iPhone resta comunque fisicamente vicino (Bluetooth) durante l'allenamento — **nessun supporto standalone via cellulare**: il Watch non parla mai direttamente con Supabase (conferma di ADR-0006), sincronizza solo via `WatchConnectivity` verso l'iPhone.
- **Navigazione**: lista scrollabile (Digital Crown) di tutti gli esercizi del giorno, non una schermata per esercizio.
- **Input peso/reps**: Digital Crown per regolare i valori, conferma con tap.
- **Modifiche ad hoc durante la sessione** (serie extra, peso diverso dal pianificato): applicate sempre prima **solo alla sessione corrente**; al termine (o subito dopo la modifica) l'app chiede esplicitamente se salvare la modifica anche nel template (`RoutineExercise.targetSets`/`targetReps`) per le prossime volte, o tenerla solo per oggi. Nessuna modifica silenziosa al template.
- **Nessuno swap esercizio dal Watch**: sostituire un esercizio pianificato con un altro si fa solo dall'iPhone o dopo l'allenamento — riduce la superficie UI su schermo piccolo.

### Stato sessione
- `WorkoutSession.status`: `active | paused | completed | cancelled` (vedi migration `0003_watch_scope.sql`). Pausa e annullamento gestibili dal Watch:
  - **Pausa**: la sessione resta `active`→`paused`, riprendibile; il timer di riposo eventualmente attivo si ferma.
  - **Annulla**: la sessione passa a `cancelled`; i `SetLog` già inseriti restano nel DB (storico grezzo, non cancellati) ma una sessione `cancelled` è esclusa da statistiche, streak e scrittura HealthKit (ADR-0004).

### Timer di riposo e haptics
- **Auto-start timer configurabile per esercizio** (`RoutineExercise.autoStartRestTimer`, default `true`): dopo aver confermato una serie, il timer parte da solo a meno che l'esercizio non lo disabiliti esplicitamente.
- **Haptics configurabili**: preferenze globali in `profiles.watch_settings` (fine riposo, serie completata, sessione completata, avviso a soglia intermedia del riposo), sovrascrivibili per singolo esercizio via `RoutineExercise.hapticsOverride`.

### Complication
- In idle (fuori sessione) mostra la **streak/costanza** (es. giorni consecutivi o allenamenti questa settimana) — valore derivato da `workout_sessions` con `status = 'completed'`, nessuna tabella dedicata.

## Conseguenze
- Il Watch diventa un client "pesante" quanto l'iPhone per il modulo `1r0-gym` (stessa logica di log, stesso SwiftData locale, stesso outbox verso l'iPhone) — più superficie da costruire/testare rispetto a un companion leggero, ma coerente con l'uso reale previsto (allenarsi senza portare il telefono in mano).
- `hapticsOverride`/`watch_settings` come `jsonb` per evitare colonne rigide per ogni singola preferenza — stesso pattern già usato per `measurements` (ADR-0012) e `proposed_changes` (ADR-0011).
- La scelta "chiede sempre" per le modifiche al template introduce un piccolo attrito UX (un prompt in più) ma evita sia sorprese (routine che cambia da sola) sia perdita di intenzione (modifica fatta e persa perché non salvata da nessuna parte).
