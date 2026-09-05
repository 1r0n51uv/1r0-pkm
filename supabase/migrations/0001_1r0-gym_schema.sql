-- Modulo 1r0-gym: schema iniziale. Vedi docs/glossary.md per i termini
-- e docs/adr/0022-backend-custom-postgres-api.md per le decisioni su
-- backend/autorizzazione (niente Supabase, niente RLS: l'autorizzazione
-- per user_id è applicata dal servizio API, non dal database).

create extension if not exists pgcrypto;

create table if not exists profiles (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source text not null check (source in ('wger', 'ai', 'custom')),
  external_id text,
  muscle_groups text[] not null default '{}',
  equipment text,
  instructions text,
  video_url text,
  image_url text,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists routines (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists routine_days (
  id uuid primary key default gen_random_uuid(),
  routine_id uuid not null references routines (id) on delete cascade,
  name text not null,
  order_index int not null default 0
);

create table if not exists routine_exercises (
  id uuid primary key default gen_random_uuid(),
  routine_day_id uuid not null references routine_days (id) on delete cascade,
  exercise_id uuid not null references exercises (id) on delete restrict,
  order_index int not null default 0,
  superset_group text,
  target_sets int not null default 3,
  target_reps text not null default '8-12',
  target_rest_seconds int not null default 90
);

create table if not exists workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  routine_day_id uuid references routine_days (id) on delete set null,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  notes text,
  source text not null default 'app' check (source in ('app', 'watch'))
);

create table if not exists set_logs (
  id uuid primary key default gen_random_uuid(),
  workout_session_id uuid not null references workout_sessions (id) on delete cascade,
  exercise_id uuid not null references exercises (id) on delete restrict,
  set_index int not null,
  weight_kg numeric not null,
  reps int not null,
  rpe numeric,
  superset_group text,
  completed_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists set_logs_session_idx on set_logs (workout_session_id);
create index if not exists set_logs_exercise_idx on set_logs (exercise_id);
create index if not exists routine_days_routine_idx on routine_days (routine_id);
create index if not exists routine_exercises_day_idx on routine_exercises (routine_day_id);
