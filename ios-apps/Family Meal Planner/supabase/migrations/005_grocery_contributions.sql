-- 005_grocery_contributions.sql
-- Additive migration: creates grocery_contributions join table.
-- Each row records how much a specific meal plan contributed to a
-- specific grocery item, so clearing a meal plan can remove its
-- contribution without wiping items that multiple meals share.
--
-- Safe to run multiple times (CREATE TABLE IF NOT EXISTS +
-- DROP POLICY IF EXISTS).

-- ============================================================
-- 1. CREATE GROCERY_CONTRIBUTIONS TABLE
-- ============================================================

create table if not exists grocery_contributions (
  id uuid primary key default gen_random_uuid(),
  grocery_item_id uuid not null references grocery_items(id) on delete cascade,
  meal_plan_id uuid not null references meal_plans(id) on delete cascade,
  quantity double precision not null default 0,
  created_at timestamptz not null default now()
);

-- Indexes for the two lookup patterns we use:
--   1. "remove all contributions for this meal plan" (on clear/reassign)
--   2. "cascade delete when a grocery item is deleted"
create index if not exists grocery_contributions_meal_plan_idx
  on grocery_contributions(meal_plan_id);

create index if not exists grocery_contributions_grocery_item_idx
  on grocery_contributions(grocery_item_id);

alter table grocery_contributions enable row level security;

-- ============================================================
-- 2. RLS POLICIES
--    Authorised via the household on the linked grocery_item.
-- ============================================================

drop policy if exists "Members can read contributions" on grocery_contributions;
drop policy if exists "Members can insert contributions" on grocery_contributions;
drop policy if exists "Members can update contributions" on grocery_contributions;
drop policy if exists "Members can delete contributions" on grocery_contributions;

create policy "Members can read contributions"
  on grocery_contributions for select
  using (exists (
    select 1 from grocery_items gi
    where gi.id = grocery_contributions.grocery_item_id
      and is_household_member(gi.household_id)
  ));

create policy "Members can insert contributions"
  on grocery_contributions for insert
  with check (exists (
    select 1 from grocery_items gi
    where gi.id = grocery_contributions.grocery_item_id
      and is_household_member(gi.household_id)
  ));

create policy "Members can update contributions"
  on grocery_contributions for update
  using (exists (
    select 1 from grocery_items gi
    where gi.id = grocery_contributions.grocery_item_id
      and is_household_member(gi.household_id)
  ));

create policy "Members can delete contributions"
  on grocery_contributions for delete
  using (exists (
    select 1 from grocery_items gi
    where gi.id = grocery_contributions.grocery_item_id
      and is_household_member(gi.household_id)
  ));
