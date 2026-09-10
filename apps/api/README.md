# apps/api — custom REST backend

Node.js + Fastify, talks straight to Postgres (`pg`), static API-key auth,
no RLS. See `docs/adr/0022-custom-backend-node-fastify.md`. Deployed as one
container in the compose stack — see `infra/`.

## Routes

| Method + path | Auth | Purpose |
|---|---|---|
| `GET /health` | public | liveness + `select 1` DB ping (spike #2 "è raggiungibile?") |
| `GET|POST /v1/profile` | Bearer | the single-user profile row |
| `1r0-gym` (ADR-0027) | Bearer | `/v1/workout-sessions`, `/v1/set-logs`, `/v1/body-measurements` — sink per l'import CSV Liftin' |
| `1r0-diet` (ADR-0017) | Bearer | `/v1/foods`, `/v1/food-search`, `/v1/meal-entries`, `/v1/nutrition-goals`, `/v1/recipes`, `/v1/planned-meals`, `/v1/shopping-list`, `/v1/water-logs`, `/v1/supplements`, `/v1/supplement-logs`, `/v1/caffeine-logs` |

Auth: every non-public route needs `Authorization: Bearer $API_KEY`.

ADR-0027 removed the gym catalog / routine-editor endpoints (`/v1/exercises*`,
`/v1/routines*`, `/v1/routine-tree`, wger sync, `/v1/exercises/ai-import`,
`/v1/plate-config`) with the client code that used them. The `exercises` /
`routines` / `plate_config` tables stay for now (`set_logs` FKs `exercises`);
a schema pass is deferred.

## Env

| var | required | notes |
|---|---|---|
| `DATABASE_URL` | yes | `postgres://user:pass@host:5432/db` |
| `API_KEY` | yes | the single static bearer token |
| `PORT` | no | default `8080` |
| `LOG_LEVEL` | no | default `info` |

## Run

Normally via `infra/docker-compose.yml`. Standalone (needs a reachable
Postgres and Node 20+):

```bash
npm install
DATABASE_URL=postgres://onepkm:onepkm@localhost:5432/onepkm \
API_KEY=dev-key \
npm start
```

No build step — plain ES modules on Node 20. Port to TypeScript when this
graduates from spike to the real backend.
