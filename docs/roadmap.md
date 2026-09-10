# Roadmap — dopo ADR-0027/0028

Stato di avanzamento dell'"Ordine di lavoro" in
[ADR-0027](adr/0027-stop-expo-hub-modulare-nativo.md#ordine-di-lavoro).
Aggiornare le spunte man mano; non è un documento di decisione (quello
resta l'ADR), solo il tracciamento di cosa manca.

## 1. Cleanup codice tagliato — **parziale**

- [x] Rimozione codice: sessione live, catalogo esercizi (wger/AI import),
  editor schede, calcolatore piastre, Siri Shortcuts, bridge Watch→sessione
  + modelli `Exercise`/`Routine`/`RoutineDay`/`RoutineExercise`/`PlateConfig`
  + test collegati. `GymData`/`GymSync`/`HealthKitService`/`ContentView`
  aggiornati di conseguenza. (`refactor(1r0-gym): ADR-0027 step 1`)
- [x] ADR-0027/0028 + emendamenti + glossario (fatto nel commit `docs:
  ADR-0027/0028`, prima del cleanup codice).
- [ ] **Spostamento in `Modules/Shared/`.** `Modules/Shared/` non esiste
  ancora. Da spostare (oggi vivono sotto `Modules/1r0-gym/`, ma li usa
  anche `1r0-diet`): `GymSync.swift`/`OutboxEntry.swift`/`SyncEngine.swift`/
  `SyncPolicy.swift` → `Modules/Shared/Sync/`; `HealthKitService.swift`/
  `HealthKitOnboardingView.swift` → `Modules/Shared/HealthKit/`;
  `GlassTheme.swift` → `Modules/Shared/UI/` (o simile). Comporta rinominare
  `GymSync` in qualcosa di neutro (es. `Outbox`/`SyncService`) dato che non
  è più solo-gym — da decidere in fase di implementazione, non bloccante.
- [ ] **Pulizia backend morta.** `apps/api/src/routes/exercises.js`,
  `routines.js`, `routinetree.js`, `plateconfig.js`, `wger.js` non sono più
  chiamate da nessun client dopo il cleanup di cui sopra. Non toccate in
  questo passaggio (tocca l'istanza EC2 live, rischio diverso dal cleanup
  client). Da decidere: rimuovere le route, o lasciarle morte finché non si
  droppano anche le tabelle relative in `supabase/migrations/`.

## 2. Motore Promemoria condiviso — **da iniziare**

`Modules/Shared/Reminders/`: regola di dominio "utente doveva fare X e non
l'ha fatto" (glossario), valutata su dati già presenti. Serve prima di
`diet` (notifiche azionabili, step 4) e di `documenti` (preavvisi scadenza,
step 6) — è un blocco condiviso, non specifico di un modulo.

## 3. `gym` reshape — **da iniziare**

Rimozione UI già fatta (step 1). Resta da **costruire**:
- Import CSV da Liftin' (`Date;Duration;Routine;Exercise;Set;Warmup;Weight;
  Reps/Time;Goal;Perception`, delimitatore `;`) → persistenza SwiftData +
  backend, merge deduplicato su `(Date + Exercise + Set)`.
- `WorkoutSession`/`SetLogEntry` da adattare a record importati **read-only**
  (oggi sono ancora nella forma pre-ADR-0027, dormienti: nessuna UI li crea).
  `SetLogEntry` guadagna `durationSeconds`/`isWarmup`, `reps` diventa
  opzionale (per gli esercizi a tempo).
- Vista storico + grafici (sostituisce Sessione/Schede/Catalogo in
  `ContentView`; oggi la shell ha solo Dieta/Progressi).
- Route backend per l'import (`apps/api`) + eventuale migrazione schema per
  i nuovi campi `SetLogEntry`.

## 4. `diet` + HealthKit read/write + notifiche azionabili — **da iniziare**

- Scrittura energia/macro su HealthKit per ogni pasto loggato.
- Lettura da HealthKit di peso, acqua, energia attiva (oggi il gateway
  HealthKit — post-cleanup — legge solo il peso, per `gym`).
- Notifiche azionabili "Hai mangiato a `<slot>`?" (Sì → `MealSlotAck`,
  Rimanda → +30 min, gestite in background) e "Hai bevuto?" (sotto quota
  proporzionata all'ora). Dipende dal motore Promemoria (step 2).

## 5. Infra HTTPS + backup — **da iniziare** ([ADR-0028](adr/0028-backend-https-e-storage-documenti.md))

- Dominio + Caddy/ACME su EC2, `API_DOMAIN` in `Secrets.swift`, rimozione
  eccezione ATS da `Info.plist`.
- `pg_dump` giornaliero cifrato → S3 (retention ~14gg).
- Cifratura at-rest lato client per i documenti (schema chiave da definire:
  passphrase utente vs chiave random in Keychain).

## 6. `documenti` — **da iniziare**

Vault documenti d'identità: `Documento` (`TipoDocumento`, campi fissi per
tipo, immagini fronte/retro via `VNDocumentCameraViewController` + libreria
foto, `dataScadenza` + preavvisi). Storage solo su device cifrato finché lo
step 5 non è pronto; poi sync. Non su `apps/web`. Preavvisi scadenza
dipendono dal motore Promemoria (step 2).

---

Non pianificato/rimandato (ADR-0027 "Fuori dalla v1"): modulo clipboard
(cattura automatica impossibile su iOS), widget (consumano uno dei 3 slot
sideload sul piano gratuito).
