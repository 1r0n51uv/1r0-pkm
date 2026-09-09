# ADR-0014: Siri Shortcuts per avviare un allenamento

## Status
**Superseded da [ADR-0027](0027-stop-expo-hub-modulare-nativo.md).** Il modulo `gym` non
avvia più sessioni di allenamento (diventa import-CSV + grafici), quindi non c'è più nulla
da avviare via Siri. `StartWorkoutIntent` / `GymShortcuts` vanno rimossi.

## Contesto
Vuoi poter dire "Ehi Siri, inizia allenamento Push" senza aprire l'app.

## Decisione
- Implementato con **App Intents** (framework Apple, iOS 16+), non il vecchio SiriKit/`NSUserActivity`: un `AppIntent` per "avvia sessione da un `RoutineDay`", parametrizzato col nome del giorno/routine, esposto sia a Siri sia come Shortcut/automazione.
- Nessun nuovo dato server-side: l'intent legge `RoutineDay` esistenti (via SwiftData locale, coerente con ADR-0006) e crea una `WorkoutSession` come farebbe l'avvio manuale dall'app.
- Solo avvio sessione nell'MVP (non "logga la serie X via voce" — troppo rischioso/ambiguo per un dato numerico).

## Conseguenze
- Richiede definire nomi/parametri "Siri-friendly" per le routine/giorni (es. evitare nomi ambigui che Siri fatica a riconoscere).
- Nessun impatto sullo schema Supabase: è un'integrazione puramente client-side sopra dati già esistenti.
