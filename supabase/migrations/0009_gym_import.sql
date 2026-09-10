-- ADR-0027 step 3 — `gym` reshape: `workout_sessions` / `set_logs` diventano
-- record **importati** dal CSV Liftin'. Niente più lifecycle di sessione,
-- niente catalogo esercizi (l'esercizio è solo un nome libero).
--
-- Additivo e retro-compatibile: le colonne vecchie restano (nullable) così le
-- route legacy `/v1/workout-sessions` e `/v1/set-logs` non si rompono.

alter table workout_sessions
  add column if not exists routine_label    text,
  add column if not exists duration_seconds integer;
alter table workout_sessions alter column status drop not null;
alter table workout_sessions alter column status set default null;

alter table set_logs
  add column if not exists exercise_name    text,
  add column if not exists duration_seconds integer,
  add column if not exists is_warmup        boolean not null default false;
alter table set_logs alter column reps drop not null;
-- l'esercizio non è più un FK obbligatorio: le righe importate hanno
-- `exercise_id` null e `exercise_name` valorizzato (il FK ammette NULL).
alter table set_logs alter column exercise_id drop not null;
