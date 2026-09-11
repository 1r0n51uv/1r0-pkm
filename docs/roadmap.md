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

## 3. `gym` reshape — **fatto**

- [x] **Modelli read-only.** `WorkoutSession` — niente più lifecycle
  `active/paused/completed`, `+routineLabel`/`durationSeconds`, `source =
  "liftin"`. `SetLogEntry` — `reps` opzionale, `+durationSeconds`/`isWarmup`,
  `exerciseId`/`Exercise` rimossi (si raggruppa per nome normalizzato,
  `SetLogEntry.normalize`). Nessuna UI li crea più.
- [x] **Parser CSV Liftin'** — `Modules/1r0-gym/Import/LiftinCSV.swift`:
  colonne per nome (non posizione), `Reps/Time` duale (intero → reps, `mm:ss`
  → durata), `Warmup` truthy, peso con virgola, `Duration` in vari formati.
  Da validare su un export reale (formato `Date`/`Duration` non documentato).
- [x] **Merge deduplicato** — `WorkoutImport.merge(csv:into:)`: dedup su
  `(giorno, Routine, esercizio normalizzato, Set)`; ri-import aggiorna in
  place, non duplica. Unit test in `LiftinCSVTests` + `WorkoutImportTests`.
- [x] **Import UI** — `ImportWorkoutsView` (file picker + riepilogo),
  `DocumentPicker` in `Modules/Shared/UI/`.
- [x] **Vista storico + grafici** — tab **Palestra** (`GymHistoryView` +
  `WorkoutSessionDetailView`): lista allenamenti, dettaglio serie per
  esercizio, grafici 1RM stimato / volume per esercizio nel tempo
  (`GymStats` sopra `GymMath`, ignora warmup / a tempo / 0 kg). `ContentView`
  = **Palestra | Dieta | Progressi** — Sessione/Schede/Catalogo sparite.
  Unit test in `GymStatsTests`.
- [x] **Backend** — outbox `workout.import` (batch delle sole righe toccate)
  → `POST /v1/workout-import` (`apps/api/src/routes/workoutimport.js`, upsert
  per UUID client, idempotente). Migrazione `supabase/migrations/
  0009_gym_import.sql`: `set_logs` — `reps` nullable, `exercise_id` nullable,
  `+exercise_name`/`+duration_seconds`/`+is_warmup`; `workout_sessions` —
  `+routine_label`/`+duration_seconds`, `status` nullable. Route legacy
  `/v1/workout-sessions` + `/v1/set-logs` **rimosse** (`sessions.js`/
  `setlogs.js` cancellati) — le sostituisce `workout-import`. **Da fare
  sull'istanza EC2**: applicare la migrazione 0009 e ridistribuire `apps/api`
  (non testati in locale — niente `node`/DB qui).

## 4. `diet` + HealthKit read/write + notifiche azionabili — **fatto**

- [x] **Gateway HealthKit** (`Modules/Shared/HealthKit/HealthKitService`)
  ricostruito: legge peso (già) + `todayDietaryWaterMl` + `todayActiveEnergyKcal`;
  scrive `saveMeal(energyKcal:proteinG:carbsG:fatG:at:)` (samples dietetici,
  best-effort one-way). `Info.plist` + `NSHealthUpdateUsageDescription`.
- [x] **Scrittura pasti** — `DietSync.logMeal` accumula i macro e chiama
  `saveMeal` (vale anche per `completePlannedMeal`).
- [x] **Quota calorica del giorno** — `NutritionMath.dailyCalorieQuota(baseKcal:
  activeEnergyKcal:)` (base + energia attiva, tetto 1200, non tocca
  `nutrition_goals`, ADR-0019 amendata). `DietTabView` legge l'energia attiva
  in `.task` e l'anello calorie usa la quota del giorno (+hint "da attività").
- [x] **"Hai mangiato a &lt;slot&gt;?"** — già `MissingMealReminder` (step 2).
- [x] **"Hai bevuto?"** — `WaterReminder` (`Modules/1r0-diet/Reminders/`): a
  orari fissi (11/14/17/20), se `WaterLog` locale + acqua HealthKit è sotto la
  quota proporzionata all'ora (`NutritionMath.waterQuotaMl`) manda un nudge
  semplice. `ReminderRule.plan` guadagna un `env: ReminderEnv` con i valori
  HealthKit pre-caricati da `RemindersEngine` (`envProvider`).
- [x] **Impostazioni notifiche** — interruttore per categoria via
  `ReminderSettings`, ora dentro `DietSettingsView` (vedi step 4bis).
- Unit test: `NutritionMathTests`, `WaterReminderTests`.
- **Da verificare su device**: nel simulatore HealthKit non ha dati/permessi,
  quindi le letture tornano 0 e la scrittura è no-op — testare con un device
  reale o dati seed in Salute (Simulatore: Health.app → Browse → aggiungi
  sample manuale, poi concedi il permesso dal toggle in Impostazioni Dieta).

## 4bis. Dieta a template settimanale + toggle Salute — **fatto** ([ADR-0029](adr/0029-dieta-settimanale-a-template-e-toggle-salute.md))

- [x] `MealSlot` implementato a 5 valori (era solo deciso in ADR-0024):
  `MealEntry.swift`, `MissingMealReminder`, `packages/shared` type. Migrazione
  `supabase/migrations/0010_meal_slot_five_values.sql` (additiva, `'snack'`
  storico resta valido a DB ma non più scritto).
- [x] `DietTemplate`/`DietTemplateItem` (SwiftData, solo locale) +
  `DietTemplateEditorView` (griglia 7 giorni × 5 slot, picker ricetta,
  "Applica a una settimana"). `DietSync.applyTemplate` traduce il template in
  `PlannedMeal` per la settimana scelta.
- [x] `DietTabView` mostra il piano **prima** del log: se uno slot ha un
  `PlannedMeal` `.planned` ma nessun `MealEntry` oggi, la card elenca gli
  alimenti pianificati con una spunta → `DietSync.completePlannedMeal`.
- [x] `HealthKitPreference` (toggle esplicito, `UserDefaults`) condiziona
  letture/scritture HealthKit del modulo diet, in aggiunta al permesso di
  sistema. `DietSettingsView` (ex `NotificationSettingsView`): Salute →
  Notifiche → Report; header Dieta con una sola icona `gearshape`.
- **Da fare sull'istanza EC2**: applicare la migrazione 0010 (non serve
  ridistribuire `apps/api`, solo `ALTER TYPE`). **Fatto** — applicata 2026-09-10.

## 4ter. Palestra — dashboard grafici multi-esercizio — **fatto** ([ADR-0030](adr/0030-palestra-dashboard-grafici-multi-esercizio.md))

- [x] `GymHistoryView`: rimosso il selettore a chip + due grafici per un
  solo esercizio, sostituito da una griglia 2 colonne con una mini-card
  (1RM stimato + sparkline) per ciascuno dei fino a 6 esercizi più allenati.
  Toccare una card apre `ExerciseChartsView` (drill-down, stessi grafici 1RM
  + volume di prima, a tutta larghezza).
- [x] Stat chip "giorni di fila" / "allenamenti sett." in testa alla vista
  (`GymMath.currentStreakDays`/`workoutsThisWeek`, funzioni pure già
  esistenti e testate, non ancora usate in nessuna UI prima d'ora).
- [x] Hook `-uitest-seed-gym` + `testGymDashboard`. 78/78 unit + 19/19 UI
  verdi.

## 4quater. Tab Impostazioni al posto di Progressi — **fatto** ([ADR-0031](adr/0031-tab-impostazioni-al-posto-di-progressi.md))

- [x] **Bug fix critico**: creare un Diet Template crashava sempre
  (`NSFetchRequest could not locate an NSEntityDescription for entity name
  'DietTemplate'`) — `DietTemplate`/`DietTemplateItem` non erano mai stati
  aggiunti a `GymData.schema` (ADR-0029 li aveva creati ma non registrati).
  Nessun test UI apriva quello schermo prima d'ora, quindi il crash non era
  stato notato. Aggiunto `testCreateDietTemplate`.
- [x] `GlassPrimaryButton`: padding orizzontale (24pt) al contenuto — con
  `.fixedSize(horizontal: true, …)` (es. "Nuovo template", "Registra
  misura") il testo toccava quasi il bordo del pulsante.
- [x] Tab "Progressi" rimossa: il suo contenuto (trend peso, misure,
  "Registra misura", import Salute) è ora la sezione "Peso e misure" di
  `GymHistoryView` (Palestra). `ProgressTabView.swift` eliminato,
  `Sparkline` spostato in `GymHistoryView.swift`.
- [x] Terza tab = "Impostazioni" (`DietSettingsView` come radice, non più
  uno sheet dall'header Dieta). Il link al Report torna un `NavigationLink`
  semplice (il giro sheet-dopo-sheet di ADR-0029 serviva solo per il caso
  "dentro un altro sheet").
- [x] XCUITest aggiornati per i nuovi percorsi (`Palestra` invece di
  `Progressi`, `Impostazioni` invece di `Dieta` → `dietSettings`). 78/78
  unit + 19/19 UI verdi.

## 4quinquies. Alimenti nel template + modifica/retroattività pasti — **fatto** ([ADR-0032](adr/0032-alimenti-nel-template-e-modifica-pasti-pianificati.md))

- [x] **Bug fix SwiftData**: assegnare una ricetta/alimento a uno slot del
  template salvava ma non compariva mai nello slot — `template.items` letto
  subito dopo (stessa vista, non un `@Query` fresco) restava stantio.
  Serviva anche `template.items.append(it)` esplicito, non solo l'inverse
  dal figlio. Vedi memoria `swiftdata-relationship-1r0-pkm`.
- [x] `DietTemplateItem` assegna una ricetta **o un alimento semplice**
  (mutuamente esclusivi); il picker riusa `FoodBasketEditor` per la sezione
  "Alimenti" (stessa ricerca/stepper del resto dell'app).
- [x] Un pasto pianificato si modifica (icona matita sulla riga, paniere
  pre-riempito) — rimuovere un alimento aggiunto per errore è il pulsante
  "✕" già esistente in `FoodBasketEditor`. Modificabile solo mentre non è
  "mangiato".
- [x] "Salta"/"Mangiato" → un solo switch (`plannedEatenToggle`); spegnerlo
  da "mangiato" cancella il `MealEntry` collegato (locale + nuova route
  `DELETE /v1/meal-entries/:id`) invece di lasciarlo orfano — è anche il
  modo per correggere retroattivamente un pasto già segnato.
- [x] Striscia giorni di `MealPlanView`: ora copre anche il passato (10
  indietro, 13 avanti, prima solo 0-6 avanti), scroll automatico su oggi.
- [x] Hook `-uitest-seed-diet` seeda 2 alimenti (non 1) per testare la
  rimozione dal paniere. Nuovi test `testAssignFoodToTemplateSlot`,
  `testEditPlannedMealRemovesFood`; `testPlanAndCompleteMeal` esteso al
  toggle andata/ritorno. 78/78 unit + UI verdi.

## 4sexies. Database prod separato da dev/test — **fatto** ([ADR-0033](adr/0033-database-prod-separato-da-dev.md))

- [x] Secondo database Postgres sulla stessa istanza/container
  (`onepkm_prod`, var `PROD_DB_NAME`), migrato con gli stessi file
  `supabase/migrations/*.sql`. `docker-compose.yml`: l'`api` ora si
  connette a `PROD_DB_NAME`, non più a `POSTGRES_DB` (che resta il
  database di bootstrap/dev-test, intatto ma non più usato dall'api).
- Nessuna modifica lato client: `Secrets.swift` punta sempre allo stesso
  host, solo l'api dietro quell'endpoint parla con un database diverso.

## 4septies. Switch database dev/prod in Impostazioni — **fatto** ([ADR-0034](adr/0034-switch-database-dev-prod-in-impostazioni.md))

- [x] Interruttore "Usa database di sviluppo" in Impostazioni
  (`DBTargetPreference`) — acceso, `ApiClient` manda `X-Db-Target: dev` su
  ogni richiesta.
- [x] Backend: due pool (`DATABASE_URL`/`DATABASE_URL_DEV`) dietro un
  `Proxy` in `db.js`, target scelto per-richiesta via `AsyncLocalStorage`
  in un hook `onRequest` — nessuna delle ~12 route toccata. Verificato
  senza race con richieste concorrenti interlacciate dev/prod.
- Non svuota la cache locale SwiftData: cambiare target a metà sessione
  mescola dati di entrambi i database finché l'app non riparte pulita
  (limite noto, documentato in `DBTargetPreference.swift`).

## 4octies. Fix ricerca alimenti (query string persa) — **fatto** ([ADR-0035](adr/0035-fix-query-string-appendingpathcomponent.md))

- [x] `ApiClient.request`: `appendingPathComponent` percent-escapava il `?`
  di ogni path con query string (es. `v1/foods/search?q=pane` →
  `…%3Fq=pane`, 404 lato server) — mai preso dagli XCUITest, che girano
  sempre offline. Fix: `URL(string:relativeTo:)`. Stesso bug colpiva anche
  `DietSync.pullPlannedMeals`, risolto insieme (stesso code path).
  Verificato in produzione: "pane" → 19 risultati, "bread" → 20.

## 4nonies. Dieta unificata + peso da Salute + rimozione voci + filtro Italia — **fatto** ([ADR-0036](adr/0036-diet-unificata-peso-salute-rimozione-voci-filtro-italia.md))

- [x] `MealPlanView` (schermata "Pianificazione" separata) assorbita in
  `DietTabView`: striscia giorni + i 5 slot con switch mangiato/saltato
  vivono sulla stessa schermata dell'anello calorie (sempre di oggi).
  `MealPlanView.swift` ora contiene solo `PlanMealSheet`.
- [x] Etichetta peso più recente da Salute sull'header Dieta
  (`healthWeightLabel`), solo informativa.
- [x] `_r0_pkm.entitlements`: rimosse due chiavi App Sandbox macOS-only,
  candidate root cause dello stop di HealthKit sui build sideload
  (SideStore/AltStore) — da confermare sulla prossima installazione.
- [x] Banner di sync fallita chiudibile (`dismissSyncBanner`), ricompare
  su un nuovo fallimento.
- [x] Rimozione voci: pasto mangiato (`DietSync.deleteMealEntry`), acqua e
  caffeina (`deleteWaterLog`/`deleteCaffeineLog`) — locale + nuove route
  `DELETE /v1/water-logs/:id` e `DELETE /v1/caffeine-logs/:id`.
- [x] Filtro "Solo Italia" nella ricerca alimenti (`FoodSearchPreference`,
  default acceso): il backend instrada verso `it.openfoodfacts.org`
  invece del dominio mondiale.

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
