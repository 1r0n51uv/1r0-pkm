# ADR-0011: Progressione automatica + coaching AI periodico

## Status
Accettata

## Contesto
Il modulo `1r0-gym` deve suggerire attivamente come progredire (peso/reps) e, nel tempo, adattare la scheda in base allo storico — non solo registrare passivamente i log.

## Decisione
- **Progressione ordinaria**: regola algoritmica deterministica lato client (double progression) — nessuna chiamata AI. Quando l'utente completa tutte le serie target di un `RoutineExercise` al reps massimo del range, l'app suggerisce +peso alla sessione successiva; altrimenti +reps.
- **Coaching periodico via Claude**: una Supabase Edge Function (`supabase/functions/coaching-review/`, da creare) viene invocata periodicamente (es. ogni 4 settimane, o su richiesta esplicita) con lo storico di `SetLog`/`WorkoutSession` della routine attiva. Claude propone modifiche strutturate (es. cambio target_sets/reps, nuovo esercizio, indicazione di deload) salvate come `CoachingSuggestion` con `status = 'pending'`.
- **Nessuna modifica automatica**: ogni `CoachingSuggestion` va accettata o rifiutata esplicitamente dall'utente; solo all'accettazione l'app applica le modifiche a `Routine`/`RoutineExercise`.

## Conseguenze
- La progressione ordinaria funziona offline (regola locale) — coerente con ADR-0006; solo la revisione periodica richiede rete.
- `coaching_suggestions` (vedi `supabase/migrations/0002_1r0-gym_expansion.sql`) mantiene uno storico dei suggerimenti anche rifiutati, utile per capire se l'AI è calibrata bene nel tempo.
- Costo: ogni invocazione della Edge Function è una chiamata Claude — periodica (non ad ogni sessione) per tenere i costi bassi.
