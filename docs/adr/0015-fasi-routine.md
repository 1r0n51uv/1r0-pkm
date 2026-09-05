# ADR-0015: Fasi su una routine (bulk/cut/deload/maintenance)

## Status
Accettata

## Contesto
Vuoi poter etichettare in che fase sei (bulk/cut/deload/mantenimento) invece di gestire più routine parallele o uno storico versioni complesso.

## Decisione
- Campo `phase` su `Routine` (`bulk | cut | deload | maintenance`, nullable — vedi migration 0002 e `RoutinePhase` in `packages/shared/src/types/1r0-gym.ts`).
- La fase è **informativa** nell'MVP: non altera automaticamente i target (`target_sets`/`target_reps`) di `RoutineExercise` — un eventuale suggerimento "deload = -40% volume" è responsabilità del coaching AI (ADR-0011), non di una regola rigida legata al campo `phase`.
- Non implementate in questo giro: routine multiple attive in parallelo, storico versioni di una routine — scartate come scope, la fase su una singola routine attiva copre il caso d'uso principale.

## Conseguenze
- Cambiare fase è manuale (l'utente sceglie quando passare da bulk a cut), niente logica automatica di periodizzazione nell'MVP.
- Se in futuro servisse davvero periodizzazione automatica strutturata (mesociclo con fasi pianificate in anticipo), va rivista con una nuova ADR — questa copre solo l'etichetta sulla routine corrente.
