-- Espansione modulo 1r0-gym: fasi routine, misure corporee, config
-- calcolatore piastre, suggerimenti di coaching AI. Vedi:
-- docs/adr/0011-progressione-automatica-coaching-ai.md
-- docs/adr/0012-body-tracking.md
-- docs/adr/0013-strumenti-in-sessione.md
-- docs/adr/0015-fasi-routine.md

alter table routines
  add column if not exists phase text check (phase in ('bulk', 'cut', 'deload', 'maintenance'));

create table if not exists body_measurements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  recorded_at timestamptz not null default now(),
  weight_kg numeric,
  measurements jsonb not null default '{}',
  photo_urls text[] not null default '{}',
  created_at timestamptz not null default now()
);

create index if not exists body_measurements_user_idx on body_measurements (user_id, recorded_at);

create table if not exists plate_set_configs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references profiles (id) on delete cascade,
  bar_weight_kg numeric not null default 20,
  available_plates_kg numeric[] not null default '{1.25,2.5,5,10,15,20,25}'
);

create table if not exists coaching_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  routine_id uuid not null references routines (id) on delete cascade,
  generated_at timestamptz not null default now(),
  summary text not null,
  proposed_changes jsonb not null default '{}',
  status text not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  reviewed_at timestamptz
);

create index if not exists coaching_suggestions_user_idx on coaching_suggestions (user_id, status);
