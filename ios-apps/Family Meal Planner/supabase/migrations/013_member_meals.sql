-- 013_member_meals.sql
-- Per-person meals, Phase 1 (ships dark — no UI reads member_id yet).
-- Design: .context/FEATURE_PER_PERSON_MEALS.md (approved 2026-08-27).
--
-- 1. household_members.user_id becomes nullable ("profile members" for
--    kids without accounts). RLS is unchanged: is_household_member()
--    matches auth.uid() = user_id, and NULL never matches, so profile
--    members can't authenticate as anyone.
-- 2. Per-member dietary_preferences (raw DietaryOption strings).
-- 3. meal_plans.member_id, NULL = the whole household (today's behavior).
--
-- Tenant safety: the composite FK (member_id, household_id) ->
-- household_members (id, household_id) means a meal can only reference
-- a member of its OWN household. RLS alone wouldn't stop a member from
-- attaching someone else's household member id (the insert policy only
-- checks is_household_member(household_id)).
--
-- CAUTION (from the design doc — easy to get wrong): ON DELETE SET NULL
-- on a composite FK nulls BOTH columns, and household_id is NOT NULL,
-- so that clause is wrong here. The FK is ON DELETE NO ACTION for
-- insert/update safety; a BEFORE DELETE trigger on household_members
-- handles cleanup by nulling member_id on that member's meals.
--
-- Safe to run multiple times (IF NOT EXISTS guards + OR REPLACE +
-- conditional constraint/trigger creation), like 004/006.

-- ============================================================
-- 1. PROFILE MEMBERS: user_id nullable
--    (unique(household_id, user_id) is untouched — Postgres treats
--    NULLs as distinct, so many profile members per household are fine.)
-- ============================================================

alter table household_members alter column user_id drop not null;

-- ============================================================
-- 2. PER-MEMBER DIETARY PREFERENCES
--    Values are raw DietaryOption enum strings ("Vegetarian",
--    "Nut-Free", ...) so the Swift enum round-trips.
-- ============================================================

alter table household_members
  add column if not exists dietary_preferences text[] not null default '{}';

-- ============================================================
-- 3. COMPOSITE KEY TARGET for the FK below
-- ============================================================

create unique index if not exists household_members_id_household_key
  on household_members (id, household_id);

-- ============================================================
-- 4. meal_plans.member_id (NULL = household meal)
-- ============================================================

alter table meal_plans add column if not exists member_id uuid;

-- ============================================================
-- 5. COMPOSITE FK — the tenant-safety mechanism.
--    ON DELETE NO ACTION on purpose; see CAUTION in the header.
-- ============================================================

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'meal_plans_member_same_household_fk'
      and conrelid = 'meal_plans'::regclass
  ) then
    alter table meal_plans
      add constraint meal_plans_member_same_household_fk
      foreign key (member_id, household_id)
      references household_members (id, household_id)
      on delete no action;
  end if;
end $$;

-- ============================================================
-- 6. MEMBER-DELETE CLEANUP TRIGGER
--    There is no app-side member-delete path yet (members only go away
--    via the auth cascade today), so the trigger is the single place
--    that detaches a deleted member's meals.
-- ============================================================

create or replace function detach_member_meals()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update meal_plans set member_id = null where member_id = old.id;
  return old;
end;
$$;

drop trigger if exists detach_member_meals_trigger on household_members;

create trigger detach_member_meals_trigger
  before delete on household_members
  for each row
  execute function detach_member_meals();
