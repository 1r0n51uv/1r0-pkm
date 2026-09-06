-- ADR-0019: contesto sulla riga di obiettivo nutrizionale, per rendere
-- leggibile lo storico append-only e permettere il ricalcolo.
--   activity_level  -> solo per mode='tdee' ('sedentary'|'moderate'|'active')
--   source_note     -> es. 'fase: cut' | 'tdee moderato @ 78.2 kg' | 'manuale'
--
-- `body_measurements` resta la tabella condivisa gym/diet per il peso
-- (ADR-0012/0019): nessuna modifica di schema qui.

alter table nutrition_goals add column if not exists activity_level text;
alter table nutrition_goals add column if not exists source_note text;
