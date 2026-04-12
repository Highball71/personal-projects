-- 004_meal_plans.sql
-- Additive migration: creates the meal_plans table for FluffyList Beta
-- Phase 1 meal planning. One recipe per (household, date) enforced by
-- the unique constraint. Forward-compatible with adding meal_type later.
--
-- Safe to run multiple times (CREATE TABLE IF NOT EXISTS +
-- DROP POLICY IF EXISTS).

-- ============================================================
-- 1. CREATE MEAL_PLANS TABLE
-- ============================================================

create table if not exists meal_plans (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  recipe_id uuid references recipes(id) on delete set null,
  date date not null,
  created_at timestamptz not null default now()
);

-- If the table already existed from an earlier partial migration,
-- make sure the columns we rely on are present.
alter table meal_plans add column if not exists recipe_id uuid references recipes(id) on delete set null;
alter table meal_plans add column if not exists date date;
alter table meal_plans add column if not exists created_at timestamptz not null default now();

-- Unique slot per household+date. One recipe per day in Phase 1.
-- (DROP + ADD because the unique name may not match if added earlier.)
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'meal_plans_household_id_date_key'
      and conrelid = 'meal_plans'::regclass
  ) then
    alter table meal_plans add constraint meal_plans_household_id_date_key unique (household_id, date);
  end if;
end $$;

alter table meal_plans enable row level security;

-- ============================================================
-- 2. RLS POLICIES
--    (uses the is_household_member() function from 001)
-- ============================================================

drop policy if exists "Members can read meal plans" on meal_plans;
drop policy if exists "Members can insert meal plans" on meal_plans;
drop policy if exists "Members can update meal plans" on meal_plans;
drop policy if exists "Members can delete meal plans" on meal_plans;

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
