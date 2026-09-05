# Contribuire a 1r0-pkm

Workflow di sviluppo — vedi `docs/adr/0021-piano-azione-workflow.md` per il
contesto completo delle decisioni.

## Branch e PR

- Un branch per task, dal nome descrittivo: `feat/<slug>`, `fix/<slug>`,
  `spike/<slug>` per gli esperimenti usa-e-getta (vedi ADR-0021).
- PR piccole, una per task/issue. Referenzia l'issue nella descrizione
  (`Closes #N`).
- Ogni PR viene rivista (da Claude Code o da un umano) prima del merge —
  niente merge diretto dopo il solo CI verde.

## TDD

- Il test si scrive **prima** del codice applicativo, a livello end-to-end
  (XCUITest per iOS/Watch, Playwright per il web) per ogni feature.
- Le regole di dominio pure (double progression, 1RM, macro, outbox) hanno
  in aggiunta unit test dedicati, più veloci da eseguire in iterazione.

## CI

- `apps/web` (lint, typecheck, build) gira su ogni PR — vedi
  `.github/workflows/web-ci.yml`.
- iOS/Watch: build e test in locale su Xcode per ora (nessun runner macOS
  in CI, vedi ADR-0021 per il perché).

## Task

- Ogni lavoro concreto è una GitHub Issue. Le decisioni di architettura
  restano nelle ADR (`docs/adr/`), non nelle issue.
