-- 016_verify.sql — read-only checks to run AFTER applying 016.
-- Nothing here writes. Run each block in the dashboard SQL editor.

-- 1. Policies on the touched tables. Diff against the EXPECTED FINAL
--    SET below (policy names exactly; cmd in parentheses).
--
--    household_members:
--      Members can leave their household                (DELETE)  [011]
--      Members can remove profile members               (DELETE)  [014]
--      Members can add profile members                  (INSERT)  [014]
--      Self-insert only into own or joined household    (INSERT)  [016 shim]
--      Users can view members of their household        (SELECT)  [live]
--      Members can update profile members               (UPDATE)  [014]
--      Members can update their own membership          (UPDATE)  [011]
--      -- GONE: "Users can join households"
--
--    recipe_ratings:
--      Members can insert ratings                       (INSERT)  [016]
--      Members can read ratings                         (SELECT)  [011]
--      Users can update their own rating                (UPDATE)  [016 — now membership-checked]
--      -- GONE: "Users can rate recipes"
--
--    meal_plans:
--      Members can delete meal plans                    (DELETE)  [live]
--      Members can insert meal plans                    (INSERT)  [016 — recipe-household check]
--      Members can read meal plans                      (SELECT)  [live, untouched]
--      Users can view meal plans                        (SELECT)  [live duplicate, untouched]
--      Members can update meal plans                    (UPDATE)  [016 — recipe-household check]
--      -- GONE: "Users can insert meal plans" (duplicate)
--
--    grocery_contributions:
--      Members can delete contributions                 (DELETE)  [005]
--      Members can insert contributions                 (INSERT)  [016 — item/plan household match]
--      Members can read contributions                   (SELECT)  [005]
--      Members can update contributions                 (UPDATE)  [016 — item/plan household match]
--
--    households (untouched by 016):
--      Owner can delete household / Owner can insert household /
--      Members and owner can read household / Owner can update household
select tablename, policyname, cmd, roles, qual, with_check
from pg_policies
where tablename in ('household_members', 'recipe_ratings',
                    'meal_plans', 'grocery_contributions', 'households')
order by tablename, cmd, policyname;

-- 2. Triggers on household_members — expect BOTH:
--    detach_member_meals_trigger (013) and
--    forbid_membership_move_trigger (016).
select tgname from pg_trigger
where tgrelid = 'public.household_members'::regclass
  and not tgisinternal
order by tgname;

-- 3. The functions exist (prosecdef = true means SECURITY DEFINER;
--    expected true for all but forbid_membership_move).
select proname, prosecdef from pg_proc
where pronamespace = 'public'::regnamespace
  and proname in ('create_household', 'join_household_by_code',
                  'is_household_member', 'forbid_membership_move')
order by proname;

-- 4. The one-rating-per-account unique index exists.
select indexname, indexdef from pg_indexes
where tablename = 'recipe_ratings'
  and indexname = 'recipe_ratings_one_per_user';

-- 5. Integrity counts — every one of these should be 0.

-- 5a. Duplicate account ratings (would have blocked the unique index).
select count(*) as duplicate_account_ratings
from (
  select recipe_id, rater_user_id
  from public.recipe_ratings
  where rater_user_id is not null
  group by recipe_id, rater_user_id
  having count(*) > 1
) d;

-- 5b. Ratings by accounts that are not members of the recipe's household.
select count(*) as nonmember_ratings
from public.recipe_ratings rr
join public.recipes r on r.id = rr.recipe_id
where rr.rater_user_id is not null
  and not exists (
    select 1 from public.household_members hm
    where hm.household_id = r.household_id
      and hm.user_id = rr.rater_user_id
  );

-- 5c. Meal plans pointing at another household's recipe.
select count(*) as cross_household_meal_plans
from public.meal_plans mp
join public.recipes r on r.id = mp.recipe_id
where r.household_id <> mp.household_id;

-- 5d. Contributions whose meal plan and grocery item disagree on household.
select count(*) as cross_household_contributions
from public.grocery_contributions gc
join public.grocery_items gi on gi.id = gc.grocery_item_id
join public.meal_plans mp on mp.id = gc.meal_plan_id
where gi.household_id <> mp.household_id;
