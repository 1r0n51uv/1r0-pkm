# apps/api — custom REST backend

Node.js + Fastify, talks straight to Postgres (`pg`), static API-key auth,
no RLS. See `docs/adr/0022-custom-backend-node-fastify.md`. Deployed as one
container in the compose stack — see `infra/`.

## Routes

| Method + path | Auth | Purpose |
|---|---|---|
| `GET /health` | public | liveness + `select 1` DB ping (spike #2 "è raggiungibile?") |
| `GET /v1/profile` | Bearer | read the single-user profile row |
| `POST /v1/profile` | Bearer | create it if missing (spike #2 "legge/scrive una riga") |
| `POST /v1/exercises/ai-import` | Bearer | former `ai-import-exercise` Edge Function (ADR-0005) |
| `POST /v1/coaching/review` | Bearer | former `coaching-review` Edge Function (ADR-0011) |

Auth: every non-public route needs `Authorization: Bearer $API_KEY`.

## Env

| var | required | notes |
|---|---|---|
| `DATABASE_URL` | yes | `postgres://user:pass@host:5432/db` |
| `API_KEY` | yes | the single static bearer token |
| `ANTHROPIC_API_KEY` | for the AI routes only | server-side only, never on the client |
| `ANTHROPIC_MODEL` | no | default `claude-sonnet-5` |
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
