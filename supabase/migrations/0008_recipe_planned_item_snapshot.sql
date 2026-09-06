-- ADR-0017 slice 2 (pianificazione pasti + ricette): allinea
-- `recipe_items` e `planned_meal_items` a `meal_entry_items`.
--
--   food_name  -> snapshot del nome, per la UI offline prima che il
--                 `food.create` in outbox (ADR-0006) sia sincronizzato.
--   food_id    -> reso nullable con ON DELETE SET NULL (era NOT NULL /
--                 RESTRICT): un alimento cancellato non deve impedire di
--                 cancellare la ricetta, e la riga resta leggibile grazie a
--                 food_name + quantity_g.

alter table recipe_items add column if not exists food_name text not null default '';
alter table planned_meal_items add column if not exists food_name text not null default '';

alter table recipe_items alter column food_id drop not null;
alter table planned_meal_items alter column food_id drop not null;

alter table recipe_items drop constraint if exists recipe_items_food_id_fkey;
alter table recipe_items add constraint recipe_items_food_id_fkey
  foreign key (food_id) references foods (id) on delete set null;

alter table planned_meal_items drop constraint if exists planned_meal_items_food_id_fkey;
alter table planned_meal_items add constraint planned_meal_items_food_id_fkey
  foreign key (food_id) references foods (id) on delete set null;
