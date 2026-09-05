# ADR-0001: Repo unico (Xcode nativo + Turborepo per la parte web/TS)

## Status
Accettata — struttura rivista dopo [ADR-0010](0010-swift-native-ios-watch.md) (Swift nativo invece di Expo).

## Contesto
1r0-pkm è pensata a moduli (`1r0-gym`, `1r0-note`, `1r0-diet`, ...) esposti da un'unica app, ma su piattaforme che non condividono più codice (iOS/Watch nativi Swift, web Next.js) da quando ADR-0010 ha sostituito Expo. Resta comunque utile un solo repo per tenere insieme codice, schema DB e documentazione delle decisioni.

## Decisione
Un unico repo con struttura:

```
apps/
  ios/       Progetto Xcode (Swift/SwiftUI) — target iOS + target watchOS
  web/       Next.js (dashboard secondaria)
packages/
  shared/    tipi TS + client Supabase condivisi SOLO tra apps/web e supabase/functions
infra/
  docker-compose self-hosted Supabase su AWS EC2, config reverse proxy
supabase/
  migrations/, functions/
docs/
  adr/, glossary.md
```

`apps/ios` è un progetto Xcode nativo, non gestito da pnpm/Turborepo — Turborepo orchestra solo `apps/web` e `packages/shared` (entrambi TS).

## Conseguenze
- `packages/shared` non serve più a evitare drift tra web e mobile (non condividono più codice) — resta utile solo per non duplicare tipi tra `apps/web` e le Supabase Edge Functions (entrambi TS/Deno-compatibili).
- Il repo mescola due mondi (Xcode nativo + pnpm/Turborepo): niente build unificata, due toolchain da conoscere. Accettato in cambio dei benefici di ADR-0010.
