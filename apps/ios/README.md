# apps/ios

Vedi `docs/adr/0010-swift-native-ios-watch.md`.

`apps/ios/1r0-pkm/1r0-pkm.xcodeproj` — target `1r0-pkm` (app iOS),
`1r0-pkm-w Watch App` (app watchOS, companion `dev.1r0.pkm`) e i rispettivi
target di test. Bundle id prefix `dev.1r0.pkm`. Il `.xcodeproj` è
binario/generato da Xcode: va modificato lì, non a mano da qui.

Gli spike #1 (Watch↔iPhone, `WatchConnectivity`) e #6 (end-to-end verso il
backend) sono validati in questi target: `PhoneConnector`/`WatchConnector`
(trasporto) e `ApiClient` (client REST) restano come base per il modulo
`1r0-gym`; il resto della UI è ancora demo.

### Setup su un checkout pulito

```
cp "apps/ios/1r0-pkm/1r0-pkm/Secrets.example.swift" \
   "apps/ios/1r0-pkm/1r0-pkm/Secrets.swift"
```
Poi compila i valori (URL backend + API key). `Secrets.swift` è gitignored
(ADR-0022). Finché il backend è HTTP su IP nudo, `Info.plist` ha
un'eccezione ATS mirata a quell'host — da togliere quando c'è un dominio +
HTTPS.

## Struttura cartelle attesa

Al momento il progetto ha ancora la struttura piatta di default di Xcode.
La struttura a moduli (vedi `docs/adr/0008-single-app-module-architecture.md`)
verrà introdotta quando si implementa il primo modulo:

```
1r0-pkm/
  App/                  entry point, DI, configurazione client API
  Modules/
    1r0-gym/
      Views/
      ViewModels/
      Models/            SwiftData models: Routine, WorkoutSession, SetLog, Exercise
      Sync/              outbox pattern verso il backend custom (ADR-0006)
  Shared/
    HealthKit/
    API/                 client REST minimale (URLSession), auth via API key statica (ADR-0022)
1r0-pkm-w Watch App/
  Modules/1r0-gym/       avvio/log sessione da Watch, SwiftData locale
```

## Capability e dipendenze

- Capability da abilitare su entrambi i target dove serve: **HealthKit**
  (vedi `docs/adr/0004-healthkit-integration.md`).
- Dipendenze via Swift Package Manager: nessuna libreria di rete esterna
  necessaria per ora — `URLSession` nativo basta per un client REST con
  API key statica (ADR-0022, niente più `supabase-swift`).
- Secrets: URL backend + API key statica (ADR-0022) in `Secrets.swift`
  (gitignored, template in `Secrets.example.swift`).

## Stato

Toolchain validata (spike #1, #2, #6). Modulo `1r0-gym` iniziato (branch
`feat/1r0-gym-*`):

- `Modules/1r0-gym/Models/` — `Exercise` (+ `source` `custom`/`wger`/`ai`,
  `externalId`, `instructions`, `videoURL`, `imageURL`, ADR-0005), `Routine`,
  `RoutineDay`, `RoutineExercise`, `WorkoutSession` (+ `routineDayId`),
  `SetLogEntry`, `PlateConfig`,
  `BodyMeasurement` (+ `source` `manual`/`healthkit`, ADR-0004)
  (SwiftData). `SupersetGroup` da modellare.
- `Modules/1r0-gym/GymMath.swift` — regole pure: Epley 1RM, volume,
  calcolatore piastre + warm-up (ADR-0013), trend peso corporeo (ADR-0012),
  double progression (ADR-0011), streak/costanza (ADR-0016). Unit test in
  `GymMathTests` (28) + `WatchSyncBridgeTests` (3) + `SiriIntentTests` (3) +
  `SyncPolicyTests` (8).
- `Modules/1r0-gym/Sync/` — `OutboxEntry` + `GymSync`. Kind supportati:
  `exercise.create`, `routine.create`, `session.create`, `session.update`,
  `setlog.create`, `plateconfig.put`, `measurement.create`,
  `routineday.create`, `routineexercise.create`.
  Retry/backoff (ADR-0006): `SyncPolicy` (backoff esponenziale con tetto 1h,
  classificazione transient/permanent degli errori HTTP); `flushOutbox`
  rispetta il backoff, parcheggia le entry "poison" (4xx / troppi tentativi)
  senza bloccare la coda, `retryFailed` le rimette in coda. `SyncEngine`
  (`@MainActor`) fa partire il flush quando torna la rete (`NWPathMonitor`),
  in foreground (scenePhase) e in background (`BGAppRefreshTask`
  `dev.1r0.pkm.sync`). Banner globale in `ContentView` quando ci sono entry
  parcheggiate.
- Watch: `WatchSessionModel` + `WatchConnector` (Watch→iPhone via
  WatchConnectivity, ADR-0016); `WatchSyncBridge` lato iPhone instrada gli
  eventi a SwiftData + outbox. UI: `WatchRootView`/`WatchLiveView`.
- `Modules/1r0-gym/Intents/` — `StartWorkoutIntent` + `GymShortcuts`
  (ADR-0014: "Ehi Siri, inizia allenamento <Giorno>"). Container condiviso
  App/Intent in `GymData`; azione in `GymActions.startWorkout`.
- `Modules/1r0-gym/HealthKit/` — `HealthKitService` (ADR-0004: salva ogni
  allenamento completato in Apple Salute come workout di forza via
  `HKWorkoutBuilder`; legge il peso corporeo più recente per l'andamento nei
  Progressi) + `HealthKitOnboardingView` (spiega i permessi prima di
  richiederli). `LiveSessionView.end()` e `WatchSyncBridge.endSession` salvano
  in Salute solo le sessioni `completed`, non le `cancelled`. Entitlement
  `com.apple.developer.healthkit` + chiavi `NSHealth*UsageDescription`.
  Watch `HKWorkoutSession` + lettura passi/calorie: da fare.
- `Modules/1r0-gym/Views/` — `GlassTheme` (Glass Dark, ADR-0023),
  `ExerciseListView` (ricerca + badge fonte) / `AddExerciseView` /
  `ImportExerciseView` (ADR-0005: "Cerca con AI" → `GymSync.aiImport`, o
  "Sincronizza catalogo wger" → `GymSync.wgerSync`; avviso di duplicato per
  nome normalizzato), `RoutineListView`/`AddRoutineView`,
  `SessionTabView` → `LiveSessionView` + `LogSetSheet` (cronometro, volume,
  1RM stimato, timer riposo visivo), `PlateCalculatorView`/`PlateConfigView`
  (ADR-0013, apribili dalla sessione), `ProgressTabView`/`AddMeasurementView`
  (ADR-0012; pulsante "import da Salute" → `HealthKitOnboardingView`, chip
  `heart.fill` sulle rilevazioni importate, ADR-0004),
  `RoutineDetailView`/`AddRoutineExerciseSheet` (ADR-0011: giorni/esercizi con
  target + suggerimento di progressione).
- Shell: `ContentView` = TabView (Sessione | Schede | Catalogo | Dieta |
  Progressi).

Modulo `1r0-diet` (ADR-0017 — slice 1: contacalorie/macro):

- `Modules/1r0-diet/Models/` — `Food` (macro per 100 g; `source`
  `custom`/`openfoodfacts`/`usda`, slice 1 solo `custom`), `MealEntry` (+
  `mealSlot` breakfast/lunch/dinner/snack) con `MealEntryItem` in cascade
  che *snapshotta* nome + calorie/macro al log (ADR-0017). Registrati nello
  stesso `GymData.schema` (container unico, ADR-0008).
- `Modules/1r0-diet/Sync/DietSync.swift` — `pullFoods` / `pullMealEntries`
  (GET `v1/foods`, `v1/meal-entries`) + azioni `createFood` / `logMeal`.
  ADR-0018: `searchRemote(_:)` (GET `v1/foods/search` — OpenFoodFacts + USDA
  via backend), `lookupBarcode(_:)` (GET `v1/foods/barcode/:code` — cache poi
  OFF), `materialize(_:)` che trasforma un `FoodCandidate` transitorio in un
  `Food` locale (riuso per barcode/external_id) + `food.create`. Outbox
  condiviso: kind `food.create` / `mealentry.create` in `GymSync.send`
  (ADR-0006).
- `Modules/1r0-diet/Views/` — `DietTabView` (mockup "GlassDiet", accento
  ambra: anello calorie + barre macro + pasti della giornata),
  `LogFoodView` ("GlassFoodSearch" + card di composizione "GlassMealLog":
  slot, ricerca cache+remota con debounce, pulsante scansione, grammi con
  anteprima macro live), `BarcodeScannerView` (VisionKit
  `DataScannerViewController`; fallback a codice manuale dove la fotocamera
  non c'è — es. simulatore; `NSCameraUsageDescription` in Info.plist),
  `AddFoodView` (alimento custom). Obiettivo calorico: costante `DietGoal`
  fissa — `NutritionGoal` append-only/TDEE/fase arriva con ADR-0019.
- Fuori slice 1 / 0018: pianificazione pasti / ricette / lista spesa,
  tracker acqua/caffeina/integratori, report (ADR-0020), modulo su Watch.

ADR-0005: modello + UI di import pronti (`ImportExerciseView`). Backend:
route `POST /v1/exercises/wger-sync` e `POST /v1/exercises/ai-import`
(`apps/api`), da deployare su EC2; l'AI import richiede `ANTHROPIC_API_KEY`
(senza chiave la app mostra un avviso, non crasha). Demo video esercizio in
UI: ancora da mostrare (il campo `videoURL` c'è).

Fuori ADR-0013 per ora: Live Activities / Dynamic Island per il timer riposo
(target widget-extension ActivityKit).

Schema: `supabase/migrations/0001_1r0-gym_schema.sql` (gym),
`0004_1r0-diet_schema.sql` + `0006_meal_item_food_name.sql` (dieta);
contratto nomi in `packages/shared/src/types/1r0-gym.ts` e `1r0-diet.ts`.
Vedi ADR-0021.
