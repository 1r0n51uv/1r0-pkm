# ADR-0021: Piano d'azione e workflow di sviluppo

## Status
Accettata

## Contesto
`1r0-gym` e `1r0-diet` sono ora ben modellati (ADR-0001–0020, 4 migration SQL). Prima di scrivere codice applicativo servono: validare i due rischi tecnici principali (Watch, backend AWS), un layout pensato prima di improvvisare in SwiftUI, e un modo di lavorare (TDD, task, branch, PR, CI) che regga nel tempo essendo un progetto solo (single dev).

## Decisione

### Ordine di lavoro
1. **Spike Watch** — Hello World bidirezionale iPhone↔Watch via `WatchConnectivity` (criterio di successo: un messaggio inviato dal Watch appare sull'iPhone e viceversa). Valida la toolchain di ADR-0010 prima di costruirci sopra il modulo `1r0-gym`.
2. **Spike AWS** — Supabase self-hosted raggiungibile dall'app (ADR-0009): istanza EC2 su, Docker Compose Supabase attivo, dominio+HTTPS via Caddy, schema applicato, un client (anche solo `curl`/Postman) che autentica e legge/scrive una riga.
3. **Layout** — mockup visivi (canvas) prima del codice: `1r0-gym` (routine + sessione live) e `1r0-diet` (log pasto + dashboard giornaliera) per primi; dashboard web e resto di `1r0-diet` quando si arriva a implementarli.
4. **Pagine di prova** — spike usa-e-getta in branch a parte per validare un flusso tecnico specifico (es. sync di un `SetLog` dal Watch fino a Supabase), scartate o riscritte bene una volta capito come farle. Solo dopo Watch+AWS+layout, perché richiedono entrambe le fondamenta.

Le fasi 1–2 sono bloccanti (nessun modulo si costruisce sopra una toolchain non validata); la fase 3 può iniziare in parallelo se c'è capacità.

### TDD
**End-to-end da subito**: per ogni feature, il test (XCUITest per iOS/Watch, Playwright per il web) si scrive prima del codice applicativo, non solo unit test sulla logica di dominio. Le regole pure (double progression, 1RM, macro, outbox) restano comunque coperte anche da unit test più mirati/veloci in aggiunta, non in sostituzione.

### Task e branch
- **GitHub Issues** per ogni task concreto (non le decisioni — quelle restano ADR). Le issue di questo piano sono già aperte nel repo.
- **Un branch per task**, PR piccole: es. `feat/watch-spike-hello-world`, `feat/aws-spike-supabase`. Niente branch "per modulo" che accumulano settimane di lavoro.
- **Review**: Claude Code rivede ogni PR prima del merge (anche essendo l'unico sviluppatore umano) — non self-merge diretto dopo il solo CI verde.

### CI
- **Solo `apps/web` per ora** su GitHub Actions (lint, typecheck, build) — vedi `.github/workflows/web-ci.yml`. iOS/Watch restano build/test locali su Xcode: un runner macOS in CI costa (minuti a pagamento oltre soglia free) e non è la priorità finché lo spike Watch non è nemmeno validato.
- Da rivalutare quando il modulo `1r0-gym` in Swift avrà una prima suite XCUITest stabile: a quel punto aggiungere un job macOS diventa più giustificato.

## Issue aperte per questo piano

1. [#1 Spike Watch Hello World](https://github.com/1r0n51uv/1r0-pkm/issues/1)
2. [#2 Spike AWS Supabase self-hosted](https://github.com/1r0n51uv/1r0-pkm/issues/2)
3. [#3 Mockup layout `1r0-gym`](https://github.com/1r0n51uv/1r0-pkm/issues/3)
4. [#4 Mockup layout `1r0-diet`](https://github.com/1r0n51uv/1r0-pkm/issues/4)
5. [#5 Setup CI web](https://github.com/1r0n51uv/1r0-pkm/issues/5)
6. [#6 Spike pagine di prova end-to-end](https://github.com/1r0n51uv/1r0-pkm/issues/6) — bloccata da #1 e #2

## Conseguenze
- TDD end-to-end da subito è ambizioso per un solo sviluppatore: rallenta l'inizio di ogni feature (si scrive il test prima di sapere esattamente come sarà l'API/UI) ma riduce il rischio di regressioni non notate, specialmente sull'outbox offline-first (ADR-0006) dove i bug sono difficili da notare a occhio.
- Niente CI iOS per ora è un compromesso consapevole: il rischio di regressioni Swift non rilevate resta finché non si automatizza — accettabile nella fase di spike/validazione, da rivedere appena il modulo `1r0-gym` ha codice reale da proteggere.
- Le PR piccole per task aumentano l'overhead di apertura/chiusura PR ma tengono ogni review (umana o di Claude) piccola e verificabile.
