-- FluffyList: Clean Supabase Schema
-- For a fresh Supabase project. No profiles table.
-- All user references point to auth.users(id).
--
-- Tables: households, household_members, recipes,
--         recipe_ingredients, meal_plans, grocery_items,
--         meal_suggestions, recipe_ratings

-- ============================================================
-- 1. HOUSEHOLDS
-- ============================================================
create table households (
  id uuid primary key default gen_random_uuid(),
  name text not null default '',
  join_code text not null unique default substring(replace(gen_random_uuid()::text, '-', '') from 1 for 6),
  owner_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

alter table households enable row level security;

-- ============================================================
-- 2. HOUSEHOLD MEMBERS (join table: auth.users <-> households)
-- ============================================================
create table household_members (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '',
  is_head_cook boolean not null default false,
  joined_at timestamptz not null default now(),
  unique(household_id, user_id)
);

alter table household_members enable row level security;

-- ============================================================
-- 3. RECIPES
-- ============================================================
create table recipes (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  name text not null default '',
  category text not null default 'dinner',
  servings smallint not null default 4,
  prep_time_minutes smallint not null default 0,
  cook_time_minutes smallint not null default 0,
  instructions text not null default '',
  is_favorite boolean not null default false,
  source_type text,
  source_detail text,
  added_by_name text,
  added_by_user_id uuid references auth.users(id),
  created_at timestamptz not null default now()
);

alter table recipes enable row level security;

-- ============================================================
-- 4. RECIPE INGREDIENTS
-- ============================================================
create table recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  name text not null default '',
  quantity double precision not null default 1.0,
  unit text not null default 'piece'
);

alter table recipe_ingredients enable row level security;

-- ============================================================
-- 5. MEAL PLANS
-- ============================================================
create table meal_plans (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  recipe_id uuid references recipes(id) on delete set null,
  date date not null,
  meal_type text not null default 'dinner',
  unique(household_id, date, meal_type)
);

alter table meal_plans enable row level security;

-- ============================================================
-- 6. GROCERY ITEMS
-- ============================================================
create table grocery_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  item_id text not null default '',
  name text not null default '',
  total_quantity double precision not null default 0,
  unit text not null default 'none',
  is_checked boolean not null default false,
  week_start date
);

alter table grocery_items enable row level security;

-- ============================================================
-- 7. MEAL SUGGESTIONS
-- ============================================================
create table meal_suggestions (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  recipe_id uuid references recipes(id) on delete cascade,
  date date not null,
  meal_type text not null default 'dinner',
  suggested_by text not null default '',
  created_at timestamptz not null default now()
);

alter table meal_suggestions enable row level security;

-- ============================================================
-- 8. RECIPE RATINGS
-- ============================================================
create table recipe_ratings (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  rater_name text not null default '',
  rater_user_id uuid references auth.users(id),
  rating smallint not null default 0,
  rated_at timestamptz not null default now(),
  unique(recipe_id, rater_name)
);

alter table recipe_ratings enable row level security;

-- ============================================================
-- RLS POLICIES
-- ============================================================

-- Helper: "is this user a member of this household?"
create or replace function is_household_member(h_id uuid)
returns boolean as $$
  select exists (
    select 1 from household_members
    where household_id = h_id
      and user_id = auth.uid()
  );
$$ language sql security definer stable;

-- HOUSEHOLDS
create policy "Members can read household"
  on households for select
  using (is_household_member(id));

create policy "Anyone can read household by join code"
  on households for select
  using (true);

create policy "Authenticated users can create household"
  on households for insert
  with check (auth.uid() = owner_id);

create policy "Owner can update household"
  on households for update
  using (owner_id = auth.uid());

-- HOUSEHOLD MEMBERS
create policy "Members can read members"
  on household_members for select
  using (is_household_member(household_id));

create policy "Users can insert themselves"
  on household_members for insert
  with check (auth.uid() = user_id);

create policy "Users can update own membership"
  on household_members for update
  using (auth.uid() = user_id);

create policy "Users can delete own membership"
  on household_members for delete
  using (auth.uid() = user_id);

-- RECIPES
create policy "Members can read recipes"
  on recipes for select
  using (is_household_member(household_id));

create policy "Members can insert recipes"
  on recipes for insert
  with check (is_household_member(household_id));

create policy "Members can update recipes"
  on recipes for update
  using (is_household_member(household_id));

create policy "Members can delete recipes"
  on recipes for delete
  using (is_household_member(household_id));

-- RECIPE INGREDIENTS
create policy "Members can read ingredients"
  on recipe_ingredients for select
  using (exists (
    select 1 from recipes r
    where r.id = recipe_ingredients.recipe_id
      and is_household_member(r.household_id)
  ));

create policy "Members can insert ingredients"
  on recipe_ingredients for insert
  with check (exists (
    select 1 from recipes r
    where r.id = recipe_ingredients.recipe_id
      and is_household_member(r.household_id)
  ));

create policy "Members can update ingredients"
  on recipe_ingredients for update
  using (exists (
    select 1 from recipes r
    where r.id = recipe_ingredients.recipe_id
      and is_household_member(r.household_id)
  ));

create policy "Members can delete ingredients"
  on recipe_ingredients for delete
  using (exists (
    select 1 from recipes r
    where r.id = recipe_ingredients.recipe_id
      and is_household_member(r.household_id)
  ));

-- MEAL PLANS
create policy "Members can read meal plans"
  on meal_plans for select
  using (is_household_member(household_id));

create policy "Members can insert meal plans"
  on meal_plans for insert
  with check (is_household_member(household_id));

create policy "Members can update meal plans"
  on meal_plans for update
  using (is_household_member(household_id));

create policy "Members can delete meal plans"
  on meal_plans for delete
  using (is_household_member(household_id));

-- GROCERY ITEMS
create policy "Members can read grocery items"
  on grocery_items for select
  using (is_household_member(household_id));

create policy "Members can insert grocery items"
  on grocery_items for insert
  with check (is_household_member(household_id));

create policy "Members can update grocery items"
  on grocery_items for update
  using (is_household_member(household_id));

create policy "Members can delete grocery items"
  on grocery_items for delete
  using (is_household_member(household_id));

-- MEAL SUGGESTIONS
create policy "Members can read suggestions"
  on meal_suggestions for select
  using (is_household_member(household_id));

create policy "Members can insert suggestions"
  on meal_suggestions for insert
  with check (is_household_member(household_id));

create policy "Members can delete suggestions"
  on meal_suggestions for delete
  using (is_household_member(household_id));

-- RECIPE RATINGS
create policy "Members can read ratings"
  on recipe_ratings for select
  using (exists (
    select 1 from recipes r
    where r.id = recipe_ratings.recipe_id
      and is_household_member(r.household_id)
  ));

create policy "Members can insert ratings"
  on recipe_ratings for insert
  with check (exists (
    select 1 from recipes r
    where r.id = recipe_ratings.recipe_id
      and is_household_member(r.household_id)
  ));

create policy "Members can update ratings"
  on recipe_ratings for update
  using (exists (
    select 1 from recipes r
    where r.id = recipe_ratings.recipe_id
      and is_household_member(r.household_id)
  ));
