-- ADR-0027 step 3 — `gym` reshape: `workout_sessions` / `set_logs` diventano
-- record **importati** dal CSV Liftin'. Niente più lifecycle di sessione,
-- niente catalogo esercizi (l'esercizio è solo un nome).
--
-- Additivo e idempotente. Le colonne vecchie restano; `status` resta con il
-- suo default 'completed' per le righe importate (il client non lo usa).

alter table workout_sessions
  add column if not exists routine_label    text,
  add column if not exists duration_seconds integer;

-- l'import usa source = 'liftin'
alter table workout_sessions drop constraint if exists workout_sessions_source_check;
alter table workout_sessions add constraint workout_sessions_source_check
  check (source = any (array['app', 'watch', 'liftin']));

alter table set_logs
  add column if not exists exercise_name    text,
  add column if not exists duration_seconds integer,
  add column if not exists is_warmup        boolean not null default false;

-- serie a tempo: niente reps; esercizio = solo un nome, niente FK obbligatorio
alter table set_logs alter column reps        drop not null;
alter table set_logs alter column exercise_id drop not null;
