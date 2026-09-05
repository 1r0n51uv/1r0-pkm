-- Modulo 1r0-diet: schema iniziale. Vedi docs/glossary.md e
-- docs/adr/0017-modulo-dieta-scope.md, 0018, 0019, 0020.
-- Riusa `profiles` e `body_measurements` (peso/misure) già create per il
-- modulo 1r0-gym — vedi ADR-0019 sul collegamento condiviso.

create table if not exists foods (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  source text not null check (source in ('openfoodfacts', 'usda', 'custom')),
  external_id text,
  barcode text,
  brand text,
  serving_size_g numeric,
  calories_per_100g numeric not null,
  protein_g_per_100g numeric not null default 0,
  carbs_g_per_100g numeric not null default 0,
  fat_g_per_100g numeric not null default 0,
  caffeine_mg_per_100g numeric,
  created_by uuid references profiles (id) on delete set null,
  created_at timestamptz not null default now()
);

create unique index if not exists foods_barcode_idx on foods (barcode) where barcode is not null;
create index if not exists foods_name_idx on foods using gin (to_tsvector('simple', name));

create table if not exists recipes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists recipe_items (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes (id) on delete cascade,
  food_id uuid not null references foods (id) on delete restrict,
  quantity_g numeric not null,
  order_index int not null default 0
);

create type meal_slot as enum ('breakfast', 'lunch', 'dinner', 'snack');

create table if not exists meal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  consumed_at timestamptz not null default now(),
  meal_slot meal_slot not null,
  recipe_id uuid references recipes (id) on delete set null,
  notes text,
  created_at timestamptz not null default now()
);

-- Macro "snapshottati" al momento del log: restano storicamente accurati
-- anche se il food_id viene corretto/aggiornato in seguito.
create table if not exists meal_entry_items (
  id uuid primary key default gen_random_uuid(),
  meal_entry_id uuid not null references meal_entries (id) on delete cascade,
  food_id uuid references foods (id) on delete set null,
  quantity_g numeric not null,
  calories numeric not null,
  protein_g numeric not null default 0,
  carbs_g numeric not null default 0,
  fat_g numeric not null default 0,
  order_index int not null default 0
);

create table if not exists planned_meals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  planned_date date not null,
  meal_slot meal_slot not null,
  recipe_id uuid references recipes (id) on delete set null,
  status text not null default 'planned' check (status in ('planned', 'completed', 'skipped')),
  meal_entry_id uuid references meal_entries (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists planned_meals_user_date_idx on planned_meals (user_id, planned_date);

create table if not exists planned_meal_items (
  id uuid primary key default gen_random_uuid(),
  planned_meal_id uuid not null references planned_meals (id) on delete cascade,
  food_id uuid not null references foods (id) on delete restrict,
  quantity_g numeric not null,
  order_index int not null default 0
);

create table if not exists shopping_list_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  food_id uuid references foods (id) on delete set null,
  custom_name text,
  quantity_text text,
  is_checked boolean not null default false,
  source text not null default 'manual' check (source in ('generated', 'manual')),
  created_at timestamptz not null default now()
);

create table if not exists water_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  logged_at timestamptz not null default now(),
  amount_ml numeric not null,
  created_at timestamptz not null default now()
);

create table if not exists supplements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  name text not null,
  dose_text text,
  schedule_text text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists supplement_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  supplement_id uuid not null references supplements (id) on delete cascade,
  logged_at timestamptz not null default now(),
  taken boolean not null default true
);

create table if not exists caffeine_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  logged_at timestamptz not null default now(),
  source_name text not null,
  caffeine_mg numeric not null,
  created_at timestamptz not null default now()
);

-- Append-only: ogni cambio obiettivo inserisce una nuova riga, quella
-- attiva è la più recente per effective_from <= oggi (vedi ADR-0019).
create table if not exists nutrition_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  mode text not null check (mode in ('manual', 'phase_linked', 'tdee')),
  calories_target numeric not null,
  protein_g_target numeric not null,
  carbs_g_target numeric not null,
  fat_g_target numeric not null,
  water_ml_target numeric,
  effective_from date not null default current_date,
  created_at timestamptz not null default now()
);

create index if not exists nutrition_goals_user_idx on nutrition_goals (user_id, effective_from desc);
