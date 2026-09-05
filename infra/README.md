# Infra — Supabase self-hosted su AWS EC2

Vedi `docs/adr/0009-self-hosted-supabase-aws.md` per il contesto/decisione.

## Panoramica

- Istanza EC2 `t3.small`/`t4g.small` (2GB RAM), Ubuntu LTS.
- Docker Compose ufficiale Supabase (`supabase/docker`, clonato sull'istanza
  — non duplicato in questo repo per non disallinearsi dagli aggiornamenti
  upstream).
- Caddy come reverse proxy davanti allo stack, per HTTPS automatico sul
  sottodominio scelto (es. `api.<tuodominio>`).
- Nessun backup automatico per l'MVP (rischio accettato, vedi ADR-0009).

## Setup (da eseguire sull'istanza EC2)

```bash
# 1. Provisioning istanza (fuori scope di questo repo: crea la EC2,
#    apri solo le porte 22/80/443 nel security group, associa un Elastic IP)

# 2. Sull'istanza:
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
# genera secret forti per POSTGRES_PASSWORD, JWT_SECRET, ANON_KEY, SERVICE_ROLE_KEY
# (vedi supabase/docker/README upstream per come generarli)
docker compose up -d

# 3. Applica lo schema di questo repo
#    dall'istanza, o da locale puntando all'host remoto:
psql "postgresql://postgres:<password>@<host>:5432/postgres" \
  -f supabase/migrations/0001_1r0-gym_schema.sql
```

## Reverse proxy (Caddy)

`Caddyfile` di esempio da mettere sull'istanza (fuori da questo repo, o in
`infra/Caddyfile` — vedi file accanto):

```
api.<tuodominio> {
  reverse_proxy localhost:8000
}
```

Caddy gestisce automaticamente il certificato Let's Encrypt al primo avvio.

## Deploy della Edge Function

`supabase/functions/ai-import-exercise/` va deployata con la Supabase CLI
puntando all'istanza self-hosted:

```bash
supabase functions deploy ai-import-exercise --project-ref <non applicabile self-hosted>
# per self-hosted: seguire la procedura "self-hosted functions" della doc
# Supabase (Docker Compose include già il container functions/edge-runtime)
```

## Non ancora fatto

- Provisioning EC2 automatizzato (Terraform/CDK) — per ora manuale.
- Backup (vedi ADR-0009: rimandato consapevolmente).
- Monitoring/alerting sull'istanza.
