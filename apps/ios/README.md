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

Toolchain validata (spike #1, #2, #6). Prossimo: implementazione del
modulo `1r0-gym` — schema in `supabase/migrations/0001_1r0-gym_schema.sql`,
tipi di riferimento in `packages/shared/src/types/1r0-gym.ts` (non
importabili da Swift ma utili come contratto dei nomi). Vedi ADR-0021.
