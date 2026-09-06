# 1r0-pkm

App personale a moduli — `1r0-pkm` è un'app della famiglia `1r0` (scope
*personal knowledge management*, gestione della vita personale): `1r0-note`
(appunti), `1r0-diet` (contacalorie), `1r0-gym` (schede + tracker), e altri
moduli in futuro. Ogni modulo vive come sezione dentro un'unica app (vedi
`docs/adr/0008-single-app-module-architecture.md`).

**Modulo in sviluppo ora: `1r0-gym`** (implementazione) **e `1r0-diet`**
(domain-modeling completato, implementazione non ancora iniziata).
Prodotto iOS-first nativo (Swift/SwiftUI), con companion Apple Watch e
integrazione HealthKit. Backend REST custom (Node.js/Fastify + Postgres)
self-hosted su AWS EC2 — vedi ADR-0022.

## Decisioni di architettura

Tutte le scelte (e le alternative scartate) sono documentate come ADR in
[`docs/adr/`](docs/adr/), con il glossario dei termini di dominio in
[`docs/glossary.md`](docs/glossary.md). Punto di partenza consigliato:

1. `0010-swift-native-ios-watch.md` — perché Swift nativo invece di Expo
2. `0009-self-hosted-supabase-aws.md` — backend self-hosted su AWS EC2 (raffina `0002`)
3. `0001-monorepo-turborepo.md` — struttura del repo
4. `0006-offline-first-workout-logging.md` — perché serve un outbox locale (SwiftData)
5. `0011`–`0015` — espansioni modulo `1r0-gym`: coaching AI periodico, body tracking, strumenti in-sessione (piastre/warm-up/Live Activities), Siri Shortcuts, fasi routine (bulk/cut/deload)
6. `0016-watch-app-scope.md` — cosa fa l'app Watch: log completo autonomo, pausa/annulla sessione, timer/haptics configurabili, streak in complication
7. `0017`–`0020` — modulo `1r0-diet`: scope (contacalorie, pasti pianificati/ricette, lista spesa, acqua/integratori/caffeina), fonte dati alimenti (OpenFoodFacts+USDA), obiettivo calorico/macro collegabile alla fase di `1r0-gym`, report/correlazioni
8. `0021-piano-azione-workflow.md` — piano d'azione: ordine di lavoro (spike Watch → AWS → layout → pagine di prova), TDD end-to-end, task/branch/PR, CI — vedi anche `CONTRIBUTING.md` e le [issue aperte](https://github.com/1r0n51uv/1r0-pkm/issues)
9. `0023-direzione-visiva-glass-dark.md` — direzione visiva scelta (Glass Dark) dopo l'esplorazione di mockup su canvas

## Struttura repo

```
apps/
  ios/       Progetto Xcode Swift/SwiftUI (iOS + Watch), vedi apps/ios/README.md
  web/       Next.js — dashboard secondaria (sola lettura per ora)
  api/       Backend REST custom (Node.js + Fastify), vedi ADR-0022 e apps/api/README.md
packages/
  shared/    tipi TS + client REST generico, usati solo da apps/web
infra/
  docker-compose: Postgres + apps/api + Caddy, su AWS EC2 — vedi infra/README.md
supabase/
  migrations/  schema SQL (fonte di verità, applicato con psql — ADR-0022)
docs/
  adr/, glossary.md
```

## Setup

Prerequisiti: Node 20+, pnpm 9+, una VM/macchina macOS con Xcode (per iOS/
Watch), un'istanza AWS EC2 per il backend (vedi `infra/README.md`).

```bash
# backend (una tantum, sull'istanza EC2)
# cd infra && cp .env.example .env && docker compose up -d --build
# vedi infra/README.md

# web
pnpm install
cp apps/web/.env.example apps/web/.env.local   # da creare: API_BASE_URL, API_KEY
pnpm --filter @1r0-pkm/web dev

# iOS/Watch: da fare su macOS/Xcode, vedi apps/ios/README.md
```

## Stato dello scaffold

Scaffold iniziale: ADR, schema DB, struttura cartelle, stub delle Edge
Functions, CI web, backlog di partenza. Prossimi passi (vedi ADR-0021 e le
issue collegate):

1. [#1](https://github.com/1r0n51uv/1r0-pkm/issues/1) Spike Watch Hello World.
2. [#2](https://github.com/1r0n51uv/1r0-pkm/issues/2) Spike Supabase self-hosted su AWS.
3. ~~[#3](https://github.com/1r0n51uv/1r0-pkm/issues/3)/[#4](https://github.com/1r0n51uv/1r0-pkm/issues/4) Mockup layout `1r0-gym`/`1r0-diet`.~~ Fatto — direzione **Glass Dark** scelta, vedi ADR-0023.
4. [#5](https://github.com/1r0n51uv/1r0-pkm/issues/5) Verifica CI web su una PR reale.
5. [#6](https://github.com/1r0n51uv/1r0-pkm/issues/6) Pagine di prova end-to-end (dopo #1 e #2).

`packages/shared/src/types/1r0-gym.ts` e `1r0-diet.ts` restano utili come
riferimento del dominio anche se non importabili da Swift — sono la fonte
di verità dei nomi usati anche nello schema SQL e nel glossario.
