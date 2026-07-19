-- 010_planned_meals.sql
-- Multiple meals per day, grouped by meal type.
--
-- The meal_plans table becomes the "planned meals" store:
--   - many rows per (household_id, date) allowed
--   - many rows per (household_id, date, meal_type) allowed
--   - sort_order controls user-visible ordering within a (date, meal_type)
--
-- Earlier migrations left the table in a mixed state:
--   - 001 created it with a meal_type column and a 3-col unique constraint
--   - 004 recreated it without meal_type and with a 2-col unique constraint
--   - 006 dropped both unique constraints
--
-- This migration reconciles that history so the columns we need are
-- present and no uniqueness remains. Idempotent.

-- ============================================================
-- 1. COLUMNS
-- ============================================================

-- meal_type: enum-like text. Allowed values are enforced in the app
-- (MealType enum: breakfast, lunch, dinner, snacks, other). We keep
-- it as text + default 'dinner' so legacy rows that were inserted
-- before meal_type existed get a sensible value.
alter table meal_plans
  add column if not exists meal_type text not null default 'dinner';

-- sort_order: position within a (date, meal_type) group. Default 0
-- so bulk-inserted rows land in insertion order.
alter table meal_plans
  add column if not exists sort_order integer not null default 0;

-- ============================================================
-- 2. BACKFILL LEGACY ROWS
-- ============================================================
-- Any row that was created before meal_type existed picked up the
-- column default, but be explicit in case a prior migration inserted
-- NULLs or empty strings.
update meal_plans
  set meal_type = 'dinner'
  where meal_type is null or meal_type = '';

update meal_plans
  set sort_order = 0
  where sort_order is null;

-- ============================================================
-- 3. DROP ANY LINGERING UNIQUENESS
-- ============================================================
-- Multiple rows per (household_id, date) and per
-- (household_id, date, meal_type) are both intentional.
alter table meal_plans
  drop constraint if exists meal_plans_household_id_date_key;

alter table meal_plans
  drop constraint if exists meal_plans_household_id_date_meal_type_key;

-- ============================================================
-- 4. INDEXES
-- ============================================================
-- Week-range queries filter by household_id and date, then sort by
-- meal_type + sort_order. One composite index covers all of that.
create index if not exists meal_plans_household_date_idx
  on meal_plans(household_id, date);
