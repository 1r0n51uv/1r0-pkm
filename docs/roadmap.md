# Roadmap — dopo ADR-0027/0028

Stato di avanzamento dell'"Ordine di lavoro" in
[ADR-0027](adr/0027-stop-expo-hub-modulare-nativo.md#ordine-di-lavoro).
Aggiornare le spunte man mano; non è un documento di decisione (quello
resta l'ADR), solo il tracciamento di cosa manca.

## 1. Cleanup codice tagliato — **fatto**

- [x] Rimozione codice: sessione live, catalogo esercizi (wger/AI import),
  editor schede, calcolatore piastre, Siri Shortcuts, bridge Watch→sessione
  + modelli `Exercise`/`Routine`/`RoutineDay`/`RoutineExercise`/`PlateConfig`
  + test collegati. `GymData`/`GymSync`/`HealthKitService`/`ContentView`
  aggiornati di conseguenza. (`refactor(1r0-gym): ADR-0027 step 1`)
- [x] ADR-0027/0028 + emendamenti + glossario (fatto nel commit `docs:
  ADR-0027/0028`, prima del cleanup codice).
- [x] **Spostamento in `Modules/Shared/`.** Creato `Modules/Shared/` con
  `API/ApiClient.swift`, `Sync/{OutboxEntry,SyncEngine,SyncPolicy}.swift` +
  `Sync/Outbox.swift` (era `GymSync`: `enum GymSync` → `enum Outbox`, solo il
  processore outbox), `HealthKit/{HealthKitService,HealthKitOnboardingView}`,
  `DesignSystem/GlassTheme.swift`. `Modules/1r0-gym/Sync/GymSync.swift` resta
  col solo `pullMeasurements`. Call site `GymSync.flushOutbox/retryFailed` →
  `Outbox.*` in gym + diet + `SyncEngine` + `ContentView`.
- [x] **Pulizia backend morta.** Rimossi `apps/api/src/routes/{exercises,
  routines,routinetree,plateconfig,wger,ai}.js` + le `register` in
  `server.js`. Le tabelle `exercises`/`routines`/`plate_config` restano in
  `supabase/migrations/` (`set_logs` FK `exercises`) — drop schema rimandato.
- [x] **Target widget-extension `1r0-pkm-wiExtension` + `LiveActivity/`**
  rimossi dal `.xcodeproj` (erano riferimenti morti: i sorgenti non
  esistevano più su disco e rompevano `xcodebuild build`). ADR-0027 "Fuori
  dalla v1: Widget".

## 2. Motore Promemoria condiviso — **fatto (motore + prima regola)**

`Modules/Shared/Reminders/`:
- `ReminderCategory` (`missing-meal` / `water` / `document-expiry`) +
  `ReminderSettings` (interruttore per categoria, `UserDefaults` — locale,
  niente sync).
- `ReminderRule` — protocollo: `plan(now:context:) -> [PlannedNotification]`
  (le notifiche che *dovrebbero* essere pendenti, valutando i dati già
  presenti) + `handleAction(...)` per le azioni custom.
- `NotificationGateway` — wrapper `UNUserNotificationCenter`: permessi,
  categorie con azioni, `reconcile(planned:)` (diff con le richieste
  pendenti "di proprietà" delle regole), `snooze(_:by:)`. È il delegate: la
  risposta a un'azione arriva anche ad app terminata (iOS rilancia in
  background per `didReceive`, ADR-0027).
- `RemindersEngine` (`@MainActor`, speculare a `SyncEngine`):
  `start(container:rules:)` + `refresh()` in foreground + `BGAppRefreshTask`
  `dev.1r0.pkm.reminders` in background. Instrada lo snooze (+30 min,
  generico) e delega il resto alla regola.

Prima regola: **`MissingMealReminder`** (`Modules/1r0-diet/Reminders/`) —
per breakfast/lunch/dinner (orari default 9:30 / 13:00 / 20:00 + 30 min di
tolleranza): notifica "«Slot»?" con "Sì" (→ `MealSlotAck`, `UserDefaults`,
gestito in background) / "Rimanda" se a quell'ora non c'è né un `MealEntry`
né un ack per la giornata. Itera `MealSlot.allCases`, quindi eredita i 5
slot di ADR-0024 appena esistono. Unit test in `MissingMealReminderTests`.

Ancora da fare (step 4): regola acqua (HealthKit), override utente degli
orari, schermata impostazioni notifiche, promuovere `MealSlotAck` a modello
se serve ai report. Step 6: `DocumentExpiryReminder`.

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
