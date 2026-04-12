-- 002_recipe_columns.sql
-- Additive migration: adds structured recipe columns and recipe_ingredients table.
-- Safe to run on a DB where recipes already has (id, household_id, name, created_at).
-- All new columns have defaults so existing rows are unaffected.

-- ============================================================
-- 1. ADD COLUMNS TO RECIPES
-- ============================================================

alter table recipes add column if not exists category text not null default 'dinner';
alter table recipes add column if not exists servings smallint not null default 4;
alter table recipes add column if not exists prep_time_minutes smallint not null default 0;
alter table recipes add column if not exists cook_time_minutes smallint not null default 0;
alter table recipes add column if not exists instructions text not null default '';
alter table recipes add column if not exists is_favorite boolean not null default false;
alter table recipes add column if not exists source_type text;
alter table recipes add column if not exists source_detail text;

-- ============================================================
-- 2. CREATE RECIPE_INGREDIENTS TABLE
-- ============================================================

create table if not exists recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references recipes(id) on delete cascade,
  name text not null default '',
  quantity double precision not null default 1.0,
  unit text not null default 'piece',
  sort_order smallint not null default 0
);

alter table recipe_ingredients enable row level security;

-- ============================================================
-- 3. RLS POLICIES FOR RECIPE_INGREDIENTS
--    (uses the is_household_member() function from 001)
-- ============================================================

-- Drop-if-exists so this migration is re-runnable.
drop policy if exists "Members can read ingredients" on recipe_ingredients;
drop policy if exists "Members can insert ingredients" on recipe_ingredients;
drop policy if exists "Members can update ingredients" on recipe_ingredients;
drop policy if exists "Members can delete ingredients" on recipe_ingredients;

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
