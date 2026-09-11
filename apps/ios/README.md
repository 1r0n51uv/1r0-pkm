# apps/ios

Vedi `docs/adr/0010-swift-native-ios-watch.md`.

`apps/ios/1r0-pkm/1r0-pkm.xcodeproj` — target `1r0-pkm` (app iOS),
`1r0-pkm-w Watch App` (app watchOS, companion `dev.1r0.pkm`) e i rispettivi
target di test. Bundle id prefix `dev.1r0.pkm`. Il `.xcodeproj` è
binario/generato da Xcode: va modificato lì, non a mano da qui.

Gli spike #1 (Watch↔iPhone, `WatchConnectivity`) e #6 (end-to-end verso il
backend) sono validati in questi target: `PhoneConnector`/`WatchConnector`
(trasporto) e `ApiClient` (client REST) restano come base. Il target Watch
è **congelato** (ADR-0027): esiste nel repo ma è fuori dalla build (niente
app Watch sideloadabile sul piano gratuito Apple).

### Setup su un checkout pulito

```
cp "apps/ios/1r0-pkm/1r0-pkm/Secrets.example.swift" \
   "apps/ios/1r0-pkm/1r0-pkm/Secrets.swift"
```
Poi compila i valori (URL backend + API key). `Secrets.swift` è gitignored
(ADR-0022). Finché il backend è HTTP su IP nudo, `Info.plist` ha
un'eccezione ATS mirata a quell'host — da togliere quando c'è un dominio +
HTTPS.

## Struttura cartelle

Architettura a moduli (`docs/adr/0008-single-app-module-architecture.md`),
ridimensionata da ADR-0027 a `gym` (storico + grafici) / `diet` / futuro
`documenti`, con infrastruttura condivisa via `Modules/Shared/`:

```
1r0-pkm/
  Modules/
    Shared/              infrastruttura condivisa dai moduli (ADR-0027)
      API/               ApiClient (URLSession, API key statica, ADR-0022)
      Sync/              OutboxEntry, Outbox (processore condiviso), SyncEngine, SyncPolicy
      HealthKit/         HealthKitService (gateway), HealthKitOnboardingView
      DesignSystem/      GlassTheme (Glass Dark, ADR-0023)
      Reminders/         ReminderCategory/Settings/Rule, NotificationGateway, RemindersEngine
      UI/                DocumentPicker
    1r0-gym/
      GymData.swift       Schema + ModelContainer unico (gym + diet, ADR-0008)
      GymMath.swift       regole pure (Epley 1RM, volume, trend peso, …)
      Models/            SwiftData: WorkoutSession, SetLogEntry (record
                          importati read-only), BodyMeasurement
      GymStats.swift      aggregazioni per lo storico (1RM/volume nel tempo)
      Import/            LiftinCSV (parser) + WorkoutImport (merge dedup)
      Sync/GymSync.swift  solo pullMeasurements (il resto è in Shared/)
      Views/             GymHistoryView (tab Palestra), ImportWorkoutsView,
                          ProgressTabView, AddMeasurementView
    1r0-diet/
      Reminders/         MissingMealReminder, WaterReminder, MealSlotAck
      Views/…            + NotificationSettingsView (interruttori promemoria)
      …                  resto invariato (ADR-0017/0018/0019/0020)
1r0-pkm-w Watch App/       congelato (ADR-0027), fuori dalla build
```

**Promemoria (ADR-0027 step 2 + 4).** `RemindersEngine` (speculare a
`SyncEngine`) parte in `_r0_pkmApp` con `[MissingMealReminder(),
WaterReminder()]` + un `envProvider` che pre-carica acqua/energia-attiva da
HealthKit; rivaluta in foreground (`refresh()`) e in background
(`BGAppRefreshTask` `dev.1r0.pkm.reminders`). Ogni regola
`plan(now:context:env:)` restituisce le `PlannedNotification` che dovrebbero
essere pendenti; il `NotificationGateway` fa il diff con la coda reale e
gestisce le azioni ("Sì" → `MealSlotAck`, "Rimanda" → +30 min) anche ad app
terminata. `WaterReminder` è un nudge semplice (nessuna azione) se il totale
acqua (WaterLog + HealthKit) è sotto la quota proporzionata all'ora.
Interruttore per categoria in `ReminderSettings` (`UserDefaults`),
`NotificationSettingsView`. `MissingMealReminder` copre
breakfast/lunch/dinner; eredita i 5 slot di ADR-0024 quando esisteranno.

## Capability e dipendenze

- Capability da abilitare su entrambi i target dove serve: **HealthKit**
  (vedi `docs/adr/0004-healthkit-integration.md`).
- Dipendenze via Swift Package Manager: nessuna libreria di rete esterna
  necessaria per ora — `URLSession` nativo basta per un client REST con
  API key statica (ADR-0022, niente più `supabase-swift`).
- Secrets: URL backend + API key statica (ADR-0022) in `Secrets.swift`
  (gitignored, template in `Secrets.example.swift`).

## Stato

Modulo `1r0-gym` ridimensionato da ADR-0027 a **storico + grafici**: sessione
live, catalogo esercizi (wger/AI import), editor schede e calcolatore
piastre sono stati **rimossi** (non solo disabilitati), insieme ai relativi
Siri Shortcut e al bridge Watch→sessione. Al loro posto (step 3 completo):
**import CSV da Liftin'** (parser + merge dedup + outbox `workout.import`) e
la tab **Palestra** con storico e grafici per esercizio.

- `Modules/1r0-gym/Models/` — `WorkoutSession`/`SetLogEntry` sono ora record
  **importati read-only** (ADR-0027): niente lifecycle, `WorkoutSession` con
  `routineLabel`/`durationSeconds`/`source="liftin"`; `SetLogEntry` con
  `reps` opzionale, `+durationSeconds`/`isWarmup`, niente più `exerciseId`
  (si raggruppa per nome normalizzato, `SetLogEntry.normalize`). Nessuna UI
  li crea: arrivano solo dall'import. `BodyMeasurement` (+ `source`
  `manual`/`healthkit`, ADR-0004) invariato, alimenta `ProgressTabView`.
- `Modules/1r0-gym/Import/` — `LiftinCSV` (parser puro dell'export Liftin':
  colonne per nome, `Reps/Time` duale reps/`mm:ss`, `Warmup` truthy) +
  `WorkoutImport.merge(csv:into:)` (dedup su giorno · routine · esercizio
  normalizzato · set; ri-import aggiorna, non duplica) + accoda una entry
  outbox `workout.import` con le sole righe toccate → `POST /v1/workout-import`
  (`Outbox`, migration 0009). Unit test: `LiftinCSVTests` +
  `WorkoutImportTests`.
- `Modules/1r0-gym/Views/GymHistoryView` — tab **Palestra**: lista
  allenamenti + `WorkoutSessionDetailView` (serie per esercizio) + grafici
  1RM stimato / volume per esercizio (`GymStats` sopra `GymMath`, ignora
  warmup / a tempo / 0 kg, `MiniLineChart`). `ImportWorkoutsView` (file
  picker `Modules/Shared/UI/DocumentPicker` + riepilogo) si apre dal suo
  header (`square.and.arrow.down`). Unit test: `GymStatsTests`.
- `Modules/1r0-gym/GymMath.swift` — **invariato** (ADR-0027): Epley 1RM,
  volume, calcolatore piastre + warm-up (ADR-0013, formule pure anche se la
  UI che le usava è stata tolta), trend peso corporeo (ADR-0012), double
  progression (ADR-0011), streak/costanza (ADR-0016).
- `Modules/1r0-gym/Sync/GymSync.swift` — solo `pullMeasurements` (misure
  corporee). Il processore dell'outbox è `Modules/Shared/Sync/Outbox.swift`
  (`enum Outbox`): kind `workout.import` + `measurement.create` + tutti i
  kind `1r0-diet` (i kind sessione-live/catalogo sono spariti con la relativa
  route). Retry/backoff (ADR-0006)
  invariato in `Modules/Shared/Sync/`: `SyncPolicy` (backoff esponenziale
  tetto 1h, classificazione transient/permanent); `Outbox.flushOutbox`
  rispetta il backoff e parcheggia le entry "poison"; `Outbox.retryFailed` le
  rimette in coda; `SyncEngine` (`@MainActor`) fa partire il flush al ritorno
  rete (`NWPathMonitor`), in foreground (scenePhase) e in background
  (`BGAppRefreshTask` `dev.1r0.pkm.sync`). Banner globale in `ContentView`
  per le entry parcheggiate.
- Watch: target congelato (ADR-0027), fuori dalla build. `WatchSyncBridge`
  (il consumer lato iPhone dei suoi eventi di sessione) è stato rimosso col
  resto della sessione live; `PhoneConnector`/`WatchConnector` (trasporto)
  restano come base per un eventuale rilancio futuro.
- `Modules/Shared/HealthKit/` — `HealthKitService` (gateway, ADR-0004
  amendata da ADR-0027): **legge** peso corporeo (Progressi), acqua ed
  energia attiva di oggi (quota calorica + promemoria acqua); **scrive**
  `saveMeal(...)` = energia + macro di ogni pasto loggato (`DietSync.logMeal`,
  best-effort one-way). Niente scrittura workout. `HealthKitOnboardingView`
  spiega i permessi. Sul simulatore non ci sono dati/permessi → letture 0,
  scrittura no-op (verificare su device).
- `Modules/Shared/DesignSystem/GlassTheme.swift` — linguaggio visivo Glass
  Dark (ADR-0023), usato da gym + diet.
- `Modules/1r0-gym/Views/` — `ProgressTabView`/`AddMeasurementView` (ADR-0012;
  pulsante "import da Salute" → `HealthKitOnboardingView`, chip `heart.fill`
  sulle rilevazioni importate, ADR-0004).
- Shell: `ContentView` = TabView (**Palestra** = `GymHistoryView` | **Dieta**
  = `DietTabView` | **Progressi** = `ProgressTabView`) — niente più Sessione/
  Schede/Catalogo.

Modulo `1r0-diet` (ADR-0017 — slice 1: contacalorie/macro):

- `Modules/1r0-diet/Models/` — `Food` (macro per 100 g; `source`
  `custom`/`openfoodfacts`/`usda`), `MealEntry` (+ `mealSlot`) con
  `MealEntryItem` in cascade che *snapshotta* nome + calorie/macro al log
  (ADR-0017), `NutritionGoal` (ADR-0019: append-only, `mode`
  manual/phase_linked/tdee, target in grammi assoluti; + `NutritionMath`
  puro per TDEE ≈ peso×fattore e preset di fase bulk/cut/deload),
  `Recipe`/`RecipeItem` + `PlannedMeal`/`PlannedMealItem` (ADR-0017
  slice 2: pasti riutilizzabili e pianificati per data, `status`
  planned/completed/skipped), `ShoppingListItem` (slice 3: `source`
  generated/manual), `WaterLog` / `Supplement` / `SupplementLog` /
  `CaffeineLog` (slice 4: tracker semplici, aggregati "di oggi" sul
  client). Registrati nello stesso `GymData.schema` (container unico,
  ADR-0008).
- `Modules/1r0-diet/Sync/DietSync.swift` — `pullFoods` / `pullMealEntries` /
  `pullGoals` + azioni `createFood` / `logMeal` / `setGoal` (sempre INSERT,
  mai update — ADR-0019) + `current(_:)` (riga più recente con
  `effectiveFrom <= oggi`). ADR-0018: `searchRemote(_:)` (GET
  `v1/foods/search` — OpenFoodFacts + USDA via backend), `lookupBarcode(_:)`
  (GET `v1/foods/barcode/:code` — cache poi OFF), `materialize(_:)`
  (`FoodCandidate` transitorio → `Food` locale, riuso per barcode/
  external_id). ADR-0017 slice 2: `pullRecipes` / `pullPlannedMeals(from:to:)`
  + `saveRecipe` / `planMeal` / `completePlannedMeal` (crea il `MealEntry` +
  stato `completed`) / `skipPlannedMeal`. Slice 3: `pullShoppingList` +
  `addShoppingItem` / `setShoppingChecked` / `deleteShoppingItem` /
  `generateShoppingList(from:existing:)` (aggiunge dai pasti pianificati, non
  rigenera). Slice 4: `pullWaterLogs` / `pullSupplements` /
  `pullSupplementLogs` / `pullCaffeineLogs` + `addWater` / `addCaffeine` /
  `addSupplement` / `deleteSupplement` / `setSupplementTaken`. Outbox
  condiviso: kind `food.create` / `mealentry.create` / `nutritiongoal.create`
  / `recipe.create` / `plannedmeal.create` / `shoppingitem.put` /
  `waterlog.create` / `supplement.put` / `supplementlog.put` /
  `caffeinelog.create` in `Outbox.send` (ADR-0006). Le date civili
  (`effective_from` / `planned_date`) usano il calendario locale.
- `Modules/1r0-diet/DietReport.swift` — funzioni pure di aggregazione per il
  report (ADR-0020): serie giornaliera calorie/macro sulla finestra
  (30/90 gg), obiettivo storicamente attivo per giorno
  (`nutrition_goals.effective_from`), media + trend kcal, aderenza al target
  (±150 kcal), serie peso da `body_measurements` + delta. Nessuna tabella
  nuova, tutto lato client.
- `Modules/1r0-diet/Views/` — `DietTabView` (mockup "GlassDiet", accento
  ambra: anello calorie + barre macro + pasti della giornata; header con
  `chart.line.uptrend.xyaxis` → `DietReportView` e `target` → obiettivo),
  `DietReportView` (mockup "GlassDietReports": fasce 30/90 gg, card calorie
  con line chart `MiniLineChart` + linea target tratteggiata + media/trend,
  anello aderenza "X giorni su Y nel target", card peso/calorie con delta),
  `LogFoodView` ("GlassFoodSearch" + card di composizione "GlassMealLog":
  slot, ricerca cache+remota con debounce, pulsante scansione, grammi con
  anteprima macro live), `BarcodeScannerView` (VisionKit
  `DataScannerViewController`; fallback a codice manuale dove la fotocamera
  non c'è — es. simulatore; `NSCameraUsageDescription` in Info.plist),
  `AddFoodView` (alimento custom), `NutritionGoalView` (ADR-0019, mockup
  "GlassNutritionGoals": segmented Manuale/Fase/TDEE, target editabili in
  manuale / calcolati read-only altrove, "Salva" = nuova riga). L'anello e
  le barre in `DietTabView` usano `DietSync.current(goals)` (fallback
  `DietGoal` fisso). La modalità "Fase" (`phase_linked`) non legge più una
  scheda esterna (ADR-0027 ha tolto `Routine` come entità): `RoutinePhase`
  (bulk/cut/deload/maintenance) vive ora in `NutritionGoal.swift` e la fase
  è un picker manuale nel foglio obiettivo, annotato in `sourceNote`
  ("fase: bulk") e riletto da `NutritionGoal.notedPhase` — niente più
  banner di "fase cambiata", la fase è quella scelta dall'utente qui.
  TDEE è una stima grezza (peso × fattore attività): manca sesso/età/altezza
  nel profilo, da aggiungere se serve un Mifflin-St Jeor vero.
- `Modules/1r0-diet/Views/` (slice 2) — `MealPlanView` (mockup pianificazione:
  striscia 7 giorni, slot per giorno, `PlanMealSheet` per pianificare da una
  ricetta o da un paniere di alimenti; ogni pasto pianificato → "Mangiato"
  crea un `MealEntry` / "Salta"), `RecipeListView` + `AddRecipeView` (CRUD
  ricette), `FoodBasketEditor` (paniere alimenti+grammi riusato da ricette e
  pianificazione). Ingresso dall'header di `DietTabView` (icona `calendar`).
- `Modules/1r0-diet/Views/` (slice 3/4) — `ShoppingListView` (lista
  spuntabile + "genera dai pasti pianificati"; icona `cart` nell'header di
  `MealPlanView`), `TrackersCard` (sul cruscotto `DietTabView`: acqua con
  barra vs `waterMlTarget` + quick-add, caffeina mg/oggi + quick-add,
  checklist integratori) + `ManageSupplementsView` (aggiungi/rimuovi
  integratori).
- Fuori 0017/0018/0019/0020: modulo dieta su Watch. (ADR-0017 completo:
  slice 1 contacalorie, 2 ricette+pianificazione, 3 lista spesa, 4 tracker.)

ADR-0005/0013/0014/0016 sono **superseded** da ADR-0027 (catalogo esercizi,
calcolatore piastre, Siri Shortcut, scope Watch): il codice client li ha
rimossi in questo cleanup. Le route backend corrispondenti in `apps/api`
(`exercises`, `routines`, `routinetree`, `plateconfig`, `wger`) non sono
ancora state toccate — restano da rimuovere o lasciare morte, task separato
non coperto da questo passaggio.

Schema: `supabase/migrations/0001_1r0-gym_schema.sql` (gym),
`0004_1r0-diet_schema.sql` + `0006_meal_item_food_name.sql` (dieta);
contratto nomi in `packages/shared/src/types/1r0-gym.ts` e `1r0-diet.ts`.
Vedi ADR-0021.
