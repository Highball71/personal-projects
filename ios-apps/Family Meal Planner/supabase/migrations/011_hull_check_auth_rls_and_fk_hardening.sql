-- Hull Check remediation: auth/onboarding trust path + cascade-delete
-- Applied to live DB 2026-05-28. Captured here to fix repo/DB drift.
-- NOTE: unique index one_owned_household_per_user(owner_id) already exists live.

-- 1. households: remove wide-open debug policies; scope to owner/member
drop policy if exists "allow_all_households" on public.households;
drop policy if exists "allow_all_household_insert" on public.households;
drop policy if exists "Anyone can read household by join code" on public.households;

create policy "Owner can insert household" on public.households
  for insert to authenticated with check (owner_id = auth.uid());
create policy "Members and owner can read household" on public.households
  for select to authenticated using (public.is_household_member(id) or owner_id = auth.uid());
create policy "Owner can update household" on public.households
  for update to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
create policy "Owner can delete household" on public.households
  for delete to authenticated using (owner_id = auth.uid());

-- 2. Prevent duplicate memberships (RPC relies on this conflict target)
alter table public.household_members
  add constraint unique_household_member unique (household_id, user_id);

-- 3. Secure join-by-code RPC
create or replace function public.join_household_by_code(p_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare h_id uuid;
begin
  select id into h_id from public.households where join_code = p_code;
  if h_id is null then raise exception 'invalid_join_code'; end if;
  insert into public.household_members (household_id, user_id)
    values (h_id, auth.uid()) on conflict (household_id, user_id) do nothing;
  return h_id;
end; $$;
revoke all on function public.join_household_by_code(text) from public, anon;
grant execute on function public.join_household_by_code(text) to authenticated;

-- 4. household_members: allow leave / edit own row
create policy "Members can update their own membership" on public.household_members
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "Members can leave their household" on public.household_members
  for delete to authenticated using (user_id = auth.uid());

-- 5. recipes: missing UPDATE policy
create policy "Members can update recipes" on public.recipes
  for update to authenticated
  using (public.is_household_member(household_id))
  with check (public.is_household_member(household_id));

-- 6. recipe_ratings: readable + updatable by author
create policy "Members can read ratings" on public.recipe_ratings
  for select to authenticated
  using (exists (select 1 from public.recipes r
                 where r.id = recipe_ratings.recipe_id
                   and public.is_household_member(r.household_id)));
create policy "Users can update their own rating" on public.recipe_ratings
  for update to authenticated
  using (auth.uid() = rater_user_id) with check (auth.uid() = rater_user_id);

-- 7. Pin search_path on is_household_member
create or replace function public.is_household_member(h_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  return exists (select 1 from public.household_members
    where household_id = h_id and user_id = auth.uid());
end; $$;

-- 8. Cascade-delete fixes
alter table public.meal_plans drop constraint meal_plans_recipe_id_fkey;
alter table public.meal_plans add constraint meal_plans_recipe_id_fkey
  foreign key (recipe_id) references public.recipes(id) on delete set null;
alter table public.meal_plans drop constraint meal_plans_household_id_fkey;
alter table public.meal_plans add constraint meal_plans_household_id_fkey
  foreign key (household_id) references public.households(id) on delete cascade;
alter table public.grocery_items drop constraint grocery_items_household_id_fkey;
alter table public.grocery_items add constraint grocery_items_household_id_fkey
  foreign key (household_id) references public.households(id) on delete cascade;
