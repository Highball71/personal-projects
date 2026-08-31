-- 014: RLS policies for profile members (household_members rows with user_id IS NULL).
-- Phase 2 of per-person meals introduced account-less profile members; 001/011
-- policies only permit writes where auth.uid() = user_id, which NULL never
-- satisfies. These scope profile-member writes to the caller's own household.
-- The `user_id is null` guard in WITH CHECK prevents forging account memberships.
-- Safe to run multiple times.

drop policy if exists "Members can add profile members" on public.household_members;
create policy "Members can add profile members" on public.household_members
  for insert to authenticated
  with check (user_id is null and public.is_household_member(household_id));

drop policy if exists "Members can update profile members" on public.household_members;
create policy "Members can update profile members" on public.household_members
  for update to authenticated
  using (user_id is null and public.is_household_member(household_id))
  with check (user_id is null and public.is_household_member(household_id));

drop policy if exists "Members can remove profile members" on public.household_members;
create policy "Members can remove profile members" on public.household_members
  for delete to authenticated
  using (user_id is null and public.is_household_member(household_id));

-- verify
select policyname, cmd from pg_policies where tablename = 'household_members' order by cmd, policyname;
