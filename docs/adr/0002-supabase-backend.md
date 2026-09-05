# ADR-0002: Supabase come backend (Postgres + Auth + Storage)

## Status
Superata da [ADR-0022](0022-custom-backend-node-fastify.md) per Auth/RLS/Storage/Edge Functions (si passa a un servizio Node.js/Fastify custom con API key statica, niente Supabase come software). La scelta di **Postgres come DB** sotto resta valida — è l'unica parte di questa ADR ancora in vigore.

## Contesto
App single-user ma multi-device (iOS, Watch, web): serve comunque un account per sincronizzare gli stessi dati tra i client. Niente budget/team per gestire infrastruttura custom da zero (per questo si sceglie Supabase come software, non un backend scritto a mano).

## Decisione
- Postgres gestito da Supabase come unico DB.
- Supabase Auth con login minimo (magic link via email) — un solo utente reale, ma l'auth abilita RLS e la sync multi-device.
- Row Level Security su tutte le tabelle, filtrate per `auth.uid()`.
- Storage Supabase per eventuali immagini/video esercizi custom.
- Edge Functions Supabase per logica server-side che non deve girare client-side (es. proxy verso Claude API per l'import AI esercizi, vedi ADR-0005).
- Hosting dell'istanza: vedi ADR-0009 (self-hosted su AWS EC2, non Supabase Cloud).

## Alternative considerate
- **Self-hosted Postgres/Docker senza Supabase** (stack custom): scartato — si perderebbero Auth/RLS/Storage/Realtime pronti all'uso, da riscrivere a mano senza reale beneficio per un progetto personale.
- **Nessun login / DB locale puro**: scartato perché serve sincronizzare iOS ↔ Watch ↔ web (vedi discussione in grilling, superata: "login minimo" scelto esplicitamente).

## Conseguenze
- Dipendenza dal software Supabase (non dal vendor cloud, visto ADR-0009); accettabile perché è Postgres puro sotto il cofano, migrabile.
- RLS va scritta fin dalla prima migration (vedi `supabase/migrations/0001_1r0-gym_schema.sql`).
