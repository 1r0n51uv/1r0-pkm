-- ADR-0017 slice 1: snapshot anche il nome dell'alimento sulla riga di
-- pasto, non solo calorie/macro. Così un Meal Entry Item resta leggibile
-- (in app, offline) anche se il Food referenziato viene rinominato o
-- cancellato (`food_id` è già `on delete set null`).

alter table meal_entry_items
  add column if not exists food_name text not null default '';
