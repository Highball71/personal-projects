-- 003_grocery_items.sql
-- Additive migration: creates the grocery_items table for FluffyList Beta
-- Phase 1 grocery list. Simpler schema than the original 001 draft —
-- no week scoping, no dedup key, no total_quantity. Just a flat list
-- per household.
--
-- Safe to run multiple times (CREATE TABLE IF NOT EXISTS +
-- DROP POLICY IF EXISTS).

-- ============================================================
-- 1. CREATE GROCERY_ITEMS TABLE
-- ============================================================

create table if not exists grocery_items (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null references households(id) on delete cascade,
  name text not null default '',
  quantity double precision not null default 1.0,
  unit text not null default 'piece',
  is_checked boolean not null default false,
  created_at timestamptz not null default now()
);

-- If the table already existed from an earlier partial migration,
-- make sure the columns we rely on are present.
alter table grocery_items add column if not exists name text not null default '';
alter table grocery_items add column if not exists quantity double precision not null default 1.0;
alter table grocery_items add column if not exists unit text not null default 'piece';
alter table grocery_items add column if not exists is_checked boolean not null default false;
alter table grocery_items add column if not exists created_at timestamptz not null default now();

alter table grocery_items enable row level security;

-- ============================================================
-- 2. RLS POLICIES
--    (uses the is_household_member() function from 001)
-- ============================================================

drop policy if exists "Members can read grocery items" on grocery_items;
drop policy if exists "Members can insert grocery items" on grocery_items;
drop policy if exists "Members can update grocery items" on grocery_items;
drop policy if exists "Members can delete grocery items" on grocery_items;

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
