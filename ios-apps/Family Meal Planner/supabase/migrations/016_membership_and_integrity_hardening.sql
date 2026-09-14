-- 016_membership_and_integrity_hardening.sql
--
-- Codex ("Astra") security review 2026-09-13. Two membership gaps and
-- three cross-table integrity rules. Reconciled 2026-09-14 against the
-- LIVE pg_policies grid from `papuusfhtojthtnbsdvs` (pasted in the PR)
-- — policy names below are the live names, which drifted from the repo
-- (e.g. the open INSERT is "Users can join households", not 001's
-- "Users can insert themselves").
--
-- NOT idempotent, on purpose: every DROP names its exact live policy
-- with no IF EXISTS — if a name is wrong, the migration must fail
-- loudly rather than leave the old permissive policy standing.
-- Permissive policies OR together, so a new tighter policy beside an
-- old open one changes nothing; the old one has to go.
--
-- 1. MEMBERSHIP GAP — direct self-insert. "Users can join households"
--    (WITH CHECK auth.uid() = user_id) let any authenticated user
--    INSERT a membership for themselves given only a household_id —
--    join-code bypass. Membership is now gained only through SECURITY
--    DEFINER functions: join_household_by_code (011) and the new
--    create_household, which inserts the households row and the
--    owner's head-cook membership together.
--
--    COMPATIBILITY SHIM (drop in a later migration once builds < 123
--    are gone from TestFlight): shipped builds still do direct inserts —
--    create (build <= 122) inserts households then household_members,
--    and join inserts household_members AFTER the RPC already did (that
--    insert always dies on unique_household_member with 23505, which
--    the app treats as success). A strict drop would break both flows
--    on every installed build. The replacement policy permits ONLY:
--      a) re-inserting a membership row you already have (guaranteed
--         23505 — grants nothing, keeps the shipped join flow alive), or
--      b) inserting yourself into a household you OWN (the shipped
--         create flow's bootstrap; you can only own your own household,
--         so no cross-tenant reach).
--    Neither arm allows joining an arbitrary household_id, which is the
--    hole Astra found. The households policies (011) are untouched —
--    shipped create needs the owner INSERT policy; it was never the gap.
--
-- 2. MEMBERSHIP GAP — UPDATE can move a row. The live UPDATE policies
--    ("Members can update their own membership", "Members can update
--    profile members") pin user_id (or NULL) but not household_id, so a
--    member could re-point a membership row at another household.
--    WITH CHECK cannot reference OLD, so this is a BEFORE UPDATE
--    trigger that raises if either column changes (the trigger route,
--    not the policy route). The trigger deliberately covers PROFILE
--    member rows too (user_id IS NULL): nothing in the app ever moves
--    a member between households — updateMember writes only
--    display_name and dietary_preferences — and a profile member
--    hopping households would drag its meals across tenants via the
--    013 composite FK.
--
-- 3. INTEGRITY (preventive — zero bad rows live today):
--    - recipe_ratings: one rating per (recipe, account); rater must be
--      a CURRENT member of the recipe's household and rate as
--      themselves. The live INSERT policy ("Users can rate recipes")
--      had NO membership check at all — any authenticated user could
--      rate any recipe_id — and the live UPDATE skipped membership (a
--      departed member could keep editing). No app code writes this
--      table today (legacy CoreData only), so tightening is free.
--    - meal_plans: recipe_id, when set, must belong to the plan's own
--      household (NULL allowed — ON DELETE SET NULL). The live table
--      carries DUPLICATE INSERT policies ("Members can insert meal
--      plans" + "Users can insert meal plans") — both are dropped, one
--      replacement created. The duplicate SELECT pair ("Members can
--      read meal plans" + "Users can view meal plans") is left alone:
--      read paths are outside this brief's scope.
--    - grocery_contributions: the linked meal_plan and grocery_item
--      must belong to the same household. (The table has no
--      household_id column; the item's household is the anchor.)
--    is_household_member(uuid) already exists (001, hardened in 011:
--    SECURITY DEFINER, pinned search_path) — reused, not recreated.
--
-- The app tolerates this migration being unapplied: build 122 and
-- earlier use only the direct-insert paths, which keep working through
-- the shim; build 123's create_household RPC call fails politely until
-- this is applied.

-- ============================================================
-- 1a. create_household RPC — households row + owner membership,
--     one definer transaction. Returns the new household row.
--     one_owned_household_per_user (012) still applies and raises
--     23505 for a second household, which the app already handles.
-- ============================================================

create or replace function public.create_household(
  p_name text,
  p_display_name text default ''
)
returns public.households
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.households;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;

  insert into public.households (name, owner_id)
    values (coalesce(p_name, ''), auth.uid())
    returning * into h;

  insert into public.household_members (household_id, user_id, display_name, is_head_cook)
    values (h.id, auth.uid(), coalesce(p_display_name, ''), true);

  return h;
end;
$$;

revoke all on function public.create_household(text, text) from public, anon;
grant execute on function public.create_household(text, text) to authenticated;

-- ============================================================
-- 1b. household_members INSERT: close the open self-insert,
--     install the compatibility shim described in the header.
-- ============================================================

drop policy "Users can join households" on public.household_members;

create policy "Self-insert only into own or joined household"
  on public.household_members
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (
      -- (a) already a member: the row is a duplicate and 23505s.
      public.is_household_member(household_id)
      -- (b) owner bootstrap: shipped create flow, own household only.
      or exists (
        select 1 from public.households h
        where h.id = household_id and h.owner_id = auth.uid()
      )
    )
  );

-- ============================================================
-- 2. household_members: membership rows never move — account members
--    AND profile members (user_id IS NULL) alike; see header.
-- ============================================================

create or replace function public.forbid_membership_move()
returns trigger
language plpgsql
as $$
begin
  if new.household_id is distinct from old.household_id
     or new.user_id is distinct from old.user_id then
    raise exception 'membership_immutable';
  end if;
  return new;
end;
$$;

create trigger forbid_membership_move_trigger
  before update on public.household_members
  for each row
  execute function public.forbid_membership_move();

-- ============================================================
-- 3a. recipe_ratings: one rating per account per recipe (partial —
--     rater_user_id is nullable and NULL rows are name-keyed by the
--     001 unique(recipe_id, rater_name)); writes must be as yourself
--     and as a current member of the recipe's household. Like the
--     live "Users can rate recipes", the new INSERT does not accept
--     NULL rater_user_id.
-- ============================================================

create unique index if not exists recipe_ratings_one_per_user
  on public.recipe_ratings (recipe_id, rater_user_id)
  where rater_user_id is not null;

drop policy "Users can rate recipes" on public.recipe_ratings;
create policy "Members can insert ratings"
  on public.recipe_ratings
  for insert to authenticated
  with check (
    rater_user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_ratings.recipe_id
        and public.is_household_member(r.household_id)
    )
  );

drop policy "Users can update their own rating" on public.recipe_ratings;
create policy "Users can update their own rating"
  on public.recipe_ratings
  for update to authenticated
  using (
    rater_user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_ratings.recipe_id
        and public.is_household_member(r.household_id)
    )
  )
  with check (
    rater_user_id = auth.uid()
    and exists (
      select 1 from public.recipes r
      where r.id = recipe_ratings.recipe_id
        and public.is_household_member(r.household_id)
    )
  );

-- ============================================================
-- 3b. meal_plans: a plan's recipe must live in the plan's household.
--     NULL recipe_id stays legal (deleted recipes: ON DELETE SET NULL).
--     Both duplicate live INSERT policies go; one replacement.
-- ============================================================

drop policy "Members can insert meal plans" on public.meal_plans;
drop policy "Users can insert meal plans" on public.meal_plans;
create policy "Members can insert meal plans"
  on public.meal_plans
  for insert to authenticated
  with check (
    public.is_household_member(household_id)
    and (
      recipe_id is null
      or exists (
        select 1 from public.recipes r
        where r.id = meal_plans.recipe_id
          and r.household_id = meal_plans.household_id
      )
    )
  );

drop policy "Members can update meal plans" on public.meal_plans;
create policy "Members can update meal plans"
  on public.meal_plans
  for update to authenticated
  using (public.is_household_member(household_id))
  with check (
    public.is_household_member(household_id)
    and (
      recipe_id is null
      or exists (
        select 1 from public.recipes r
        where r.id = meal_plans.recipe_id
          and r.household_id = meal_plans.household_id
      )
    )
  );

-- ============================================================
-- 3c. grocery_contributions: the linked meal_plan must belong to the
--     same household as the linked grocery_item (which is what the
--     existing policies key membership off).
-- ============================================================

drop policy "Members can insert contributions" on public.grocery_contributions;
create policy "Members can insert contributions"
  on public.grocery_contributions
  for insert to authenticated
  with check (
    exists (
      select 1
      from public.grocery_items gi
      join public.meal_plans mp on mp.id = grocery_contributions.meal_plan_id
      where gi.id = grocery_contributions.grocery_item_id
        and gi.household_id = mp.household_id
        and public.is_household_member(gi.household_id)
    )
  );

drop policy "Members can update contributions" on public.grocery_contributions;
create policy "Members can update contributions"
  on public.grocery_contributions
  for update to authenticated
  using (
    exists (
      select 1 from public.grocery_items gi
      where gi.id = grocery_contributions.grocery_item_id
        and public.is_household_member(gi.household_id)
    )
  )
  with check (
    exists (
      select 1
      from public.grocery_items gi
      join public.meal_plans mp on mp.id = grocery_contributions.meal_plan_id
      where gi.id = grocery_contributions.grocery_item_id
        and gi.household_id = mp.household_id
        and public.is_household_member(gi.household_id)
    )
  );
