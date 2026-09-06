# Infra — backend stack on AWS EC2

Custom backend per `docs/adr/0022-custom-backend-node-fastify.md` (superseded
Supabase; Postgres on EC2 from ADR-0009 still stands). One `docker compose`
stack: **Postgres + Fastify API (`apps/api`) + Caddy** reverse proxy.

This is spike #2 (issue #2): stand the stack up on an EC2 box and prove a
client can reach it, authenticate, and read/write a row.

## Stack

| service | image / build | role |
|---|---|---|
| `db` | `postgres:16-alpine` | the only datastore. `supabase/migrations/*.sql` mounted into `/docker-entrypoint-initdb.d`, applied in order on first init. |
| `api` | build `../apps/api` | Fastify, talks to `db` directly, static API-key auth, no RLS. Not published — only Caddy reaches it. |
| `caddy` | `caddy:2-alpine` | ports 80/443. Plain HTTP by IP (`API_DOMAIN=:80`) or automatic HTTPS once `API_DOMAIN` is a real hostname. |

Volumes: `pgdata` (Postgres), `caddy_data` + `caddy_config` (certs/state).

## Deploy on EC2

```bash
# 1. Provision (outside this repo): an EC2 instance (t3.small / t4g.small,
#    2GB RAM, Ubuntu LTS), Elastic IP, security group opening 22/80/443 only.
#    Install Docker + the compose plugin.

# 2. On the instance:
git clone <this repo> && cd 1r0-pkm/infra
cp .env.example .env
#    edit .env: strong POSTGRES_PASSWORD, API_KEY (openssl rand -hex 32),
#    ANTHROPIC_API_KEY if you want the AI routes, and API_DOMAIN
#    (leave :80 for now, or set api.<yourdomain> after pointing DNS here)
docker compose up -d --build
docker compose ps          # all healthy?
docker compose logs -f api
```

The schema is applied automatically the first time `db` starts (empty
volume). To re-apply after changing migrations, recreate the volume:
`docker compose down -v && docker compose up -d` (destroys data).

## Verify (spike #2 success criterion)

From your machine, against the EC2 public IP (or the domain):

```bash
BASE=http://<ec2-ip>        # or https://api.<yourdomain>
KEY=<the API_KEY from .env>

curl -s $BASE/health
# -> {"status":"ok","db":true}

curl -s -X POST $BASE/v1/profile -H "Authorization: Bearer $KEY"
# -> 201 {"id":"...","created_at":"..."}    (creates the single-user profile)

curl -s $BASE/v1/profile -H "Authorization: Bearer $KEY"
# -> 200 {"id":"...","created_at":"..."}    (reads it back)

curl -s -o /dev/null -w '%{http_code}\n' $BASE/v1/profile
# -> 401    (no bearer token)
```

Health OK + an authed write + read-back + a 401 without the key = spike #2
done. Tick issue #2.

## Catalogo esercizi (ADR-0005)

Import una tantum del database wger (inglese) nella tabella `exercises`
(`source = 'wger'`). Idempotente: rilanciarlo aggiorna solo le righe
esistenti (l'`uuid` wger è usato come `id` della riga).

```bash
curl -s -X POST $BASE/v1/exercises/wger-sync \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '{"max": 1000}'
# -> {"pages":9,"fetched":871,"inserted":871,"updated":0,"skipped":N}
```

Import assistito da AI di un singolo esercizio non presente a catalogo
(richiede `ANTHROPIC_API_KEY` nel `.env`; senza chiave risponde 500 e la app
mostra un avviso):

```bash
curl -s -X POST $BASE/v1/exercises/ai-import \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '{"query": "jefferson curl"}'
# -> {"name":"Jefferson Curl","muscleGroups":[...],"equipment":...,"instructions":"..."}
# la app fa confermare/modificare all'utente, poi POST /v1/exercises con source:"ai"
```

## Dieta — contacalorie (ADR-0017 slice 1)

Alimento custom + pasto loggato. Client-supplied UUID, upsert idempotente
(outbox, ADR-0006). Richiede la migration `0006_meal_item_food_name.sql`.

```bash
curl -s -X POST $BASE/v1/foods \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '{"name":"Petto di pollo alla griglia","source":"custom","caloriesPer100g":195,"proteinGPer100g":31,"carbsGPer100g":0,"fatGPer100g":7}'
# -> {"id":...,"name":"Petto di pollo alla griglia","source":"custom",...}

curl -s -X POST $BASE/v1/meal-entries \
  -H "Authorization: Bearer $KEY" -H 'content-type: application/json' \
  -d '{"mealSlot":"lunch","items":[{"foodName":"Petto di pollo","quantityG":150,"calories":293,"proteinG":47,"carbsG":0,"fatG":11,"orderIndex":0}]}'
# -> {"id":...,"meal_slot":"lunch",...}

curl -s $BASE/v1/meal-entries -H "Authorization: Bearer $KEY" | jq '.[0]'
```

## Not done yet

- Provisioning automation (Terraform/CDK) — manual for now.
- Backups (ADR-0009: deferred deliberately). Simplest later: `pg_dump` to S3 on a cron.
- Monitoring/alerting on the instance.
- `packages/shared/src/supabase/` and several ADRs still say "Supabase" in
  prose — historical; ADR-0022 is the correction of record.
