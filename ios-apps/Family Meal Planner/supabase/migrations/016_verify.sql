-- 016_verify.sql — read-only checks to run AFTER applying 016.
-- Nothing here writes. Run each block in the dashboard SQL editor.

-- 1. Policies on the four touched tables. Expect on household_members:
--    NO "Users can insert themselves"; the new "Self-insert only into
--    own or joined household"; the 014 profile-member trio; the
--    001/011 select/update/delete policies. recipe_ratings: insert +
--    "Users can update their own rating" (membership-checked), select.
--    meal_plans / grocery_contributions: the household-match versions.
select tablename, policyname, cmd, qual, with_check
from pg_policies
where tablename in ('household_members', 'recipe_ratings',
                    'meal_plans', 'grocery_contributions')
order by tablename, cmd, policyname;

-- 2. The membership-move trigger and the create_household function exist.
select tgname from pg_trigger
where tgrelid = 'public.household_members'::regclass
  and tgname = 'forbid_membership_move_trigger';

select proname, prosecdef from pg_proc
where pronamespace = 'public'::regnamespace
  and proname in ('create_household', 'join_household_by_code',
                  'is_household_member', 'forbid_membership_move');

-- 3. The one-rating-per-account unique index exists.
select indexname, indexdef from pg_indexes
where tablename = 'recipe_ratings'
  and indexname = 'recipe_ratings_one_per_user';

-- 4. Integrity counts — every one of these should be 0.

-- 4a. Duplicate account ratings (would have blocked the unique index).
select count(*) as duplicate_account_ratings
from (
  select recipe_id, rater_user_id
  from public.recipe_ratings
  where rater_user_id is not null
  group by recipe_id, rater_user_id
  having count(*) > 1
) d;

-- 4b. Ratings by accounts that are not members of the recipe's household.
select count(*) as nonmember_ratings
from public.recipe_ratings rr
join public.recipes r on r.id = rr.recipe_id
where rr.rater_user_id is not null
  and not exists (
    select 1 from public.household_members hm
    where hm.household_id = r.household_id
      and hm.user_id = rr.rater_user_id
  );

-- 4c. Meal plans pointing at another household's recipe.
select count(*) as cross_household_meal_plans
from public.meal_plans mp
join public.recipes r on r.id = mp.recipe_id
where r.household_id <> mp.household_id;

-- 4d. Contributions whose meal plan and grocery item disagree on household.
select count(*) as cross_household_contributions
from public.grocery_contributions gc
join public.grocery_items gi on gi.id = gc.grocery_item_id
join public.meal_plans mp on mp.id = gc.meal_plan_id
where gi.household_id <> mp.household_id;
