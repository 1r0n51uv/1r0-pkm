# apps/ios

Vedi `docs/adr/0010-swift-native-ios-watch.md`.

Il progetto Xcode **esiste** ora — creato per lo spike #1 (Watch↔iPhone):
`apps/ios/1r0-pkm/1r0-pkm.xcodeproj`, con i target `1r0-pkm` (app iOS),
`1r0-pkm-w Watch App` (app watchOS, companion `1r0n51uv.1r0-pkm`) e i
rispettivi target di test. Bundle id prefix `1r0n51uv.1r0-pkm`. Il
`.xcodeproj` è binario/generato da Xcode: va modificato lì, non a mano da
qui. Lo spike #1 è implementato in questi target — vedi
`apps/ios/spike-watch-hello-world/README.md`.

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
1r0-pkm-watch/
  Modules/1r0-gym/       avvio/log sessione da Watch, SwiftData locale
```

## Capability e dipendenze

- Capability da abilitare su entrambi i target dove serve: **HealthKit**
  (vedi `docs/adr/0004-healthkit-integration.md`).
- Dipendenze via Swift Package Manager: nessuna libreria di rete esterna
  necessaria per ora — `URLSession` nativo basta per un client REST con
  API key statica (ADR-0022, niente più `supabase-swift`).
- `.env`/secrets: URL del servizio backend e API key statica (ADR-0022)
  in un file di config non committato (es. `Config.xcconfig`
  ignorato da git, o `Secrets.swift` generato a build time).

## Stato

Progetto Xcode creato per lo spike #1; nessun codice di modulo ancora
scritto. Il modulo `1r0-gym` (schema in
`supabase/migrations/0001_1r0-gym_schema.sql`, tipi di riferimento in
`packages/shared/src/types/1r0-gym.ts` — utile come riferimento anche se
non importabile da Swift) è il primo da implementare, ma resta bloccato
dagli spike #1 (Watch↔iPhone) e #2 (backend raggiungibile) finché non
sono validati — vedi ADR-0021.
