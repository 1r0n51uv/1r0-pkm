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

- `Modules/1r0-gym/Models/` — `Exercise`, `Routine`, `WorkoutSession`,
  `SetLogEntry`, `PlateConfig` (SwiftData). `RoutineDay`, `RoutineExercise`,
  `SupersetGroup` ancora da modellare in codice.
- `Modules/1r0-gym/GymMath.swift` — regole pure: Epley 1RM, volume,
  calcolatore piastre (`platesPerSide`), rampa warm-up 40/60/80%
  (ADR-0013). 13 unit test in `1r0-pkmTests/GymMathTests`.
- `Modules/1r0-gym/Sync/` — `OutboxEntry` + `GymSync`. Kind supportati:
  `exercise.create`, `routine.create`, `session.create`, `session.update`,
  `setlog.create`. Retry con backoff / BackgroundTasks: da fare.
- `Modules/1r0-gym/Views/` — `GlassTheme` (Glass Dark, ADR-0023),
  `ExerciseListView`/`AddExerciseView`, `RoutineListView`/`AddRoutineView`,
  `SessionTabView` → `LiveSessionView` + `LogSetSheet` (cronometro, volume,
  1RM stimato, timer riposo visivo), `PlateCalculatorView`/`PlateConfigView`
  (ADR-0013, apribili dalla sessione).
- Shell: `ContentView` = TabView (Sessione | Schede | Catalogo).

Fuori ADR-0013 per ora: demo video esercizio (serve import wger/AI,
ADR-0005), Live Activities / Dynamic Island per il timer riposo
(target widget-extension ActivityKit).

Schema: `supabase/migrations/0001_1r0-gym_schema.sql`; contratto nomi in
`packages/shared/src/types/1r0-gym.ts`. Vedi ADR-0021.
