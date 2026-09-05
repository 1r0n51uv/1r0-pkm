# ADR-0012: Tracking corporeo (peso, foto, misure)

## Status
Accettata — `body_measurements` diventata trasversale (condivisa col modulo `1r0-diet`) in [ADR-0019](0019-nutrition-goals.md).

## Contesto
Vuoi correlare l'andamento fisico (peso, foto, misure a nastro) con le performance in palestra (volume, PR), non solo loggare gli allenamenti.

## Decisione
- Nuova tabella `body_measurements` (vedi `supabase/migrations/0002_1r0-gym_expansion.sql`): peso opzionale (può arrivare anche da HealthKit, ADR-0004), misure in un campo `jsonb` a chiavi libere (es. `armLeftCm`, `waistCm`) per non dover migrare lo schema ogni volta che si aggiunge un punto di misura, foto come array di path su Supabase Storage (self-hosted, ADR-0009).
- La correlazione con le performance (volume/PR) è una vista/calcolo lato client che incrocia `body_measurements.recorded_at` con `set_logs`/`workout_sessions` per range di date — nessuna tabella dedicata, è un report derivato.
- Le foto restano nel modulo `1r0-gym` per ora (non un modulo "corpo" a sé), da rivalutare quando/se nascerà il modulo `1r0-diet` (dove il peso corporeo è rilevante anche lì).

## Conseguenze
- Storage foto su Supabase self-hosted: nessun backup (ADR-0009) — le foto sono l'asset più a rischio di perdita irreversibile del progetto, vale la pena rivedere il backup prima che se ne accumulino molte.
- Schema `jsonb` per le misure evita migrazioni frequenti ma perde la validazione a livello DB (va validata lato client/Swift).
