-- v2_migration_drift_check.sql
-- Read-only. Paste into the dashboard SQL editor on FluffyList V2
-- (papuusfhtojthtnbsdvs). One row per signature object that a repo
-- migration (001–015) creates or removes; ok = false means that
-- migration (or part of it) is missing on this database.
--
-- Written 2026-09-24 after recipes.homemade_image_path came back
-- 42703 (undefined column) — migration 007 was never applied to V2.
-- Every check below is derived from the migration files themselves,
-- not from memory. 009 is data-only (destructive dedupe), so its row
-- is informational: it checks the OUTCOME (no duplicate name groups),
-- which can also go false again through ordinary use.
--
-- Storage (bucket + policies) is 018's job and checked by 018_verify.sql.

select migration, object, ok
from (

-- ============ 001: initial schema ============
select '001' as migration, 'table public.households' as object,
       to_regclass('public.households') is not null as ok
union all select '001', 'table public.household_members',
       to_regclass('public.household_members') is not null
union all select '001', 'table public.recipes',
       to_regclass('public.recipes') is not null
union all select '001', 'table public.recipe_ingredients',
       to_regclass('public.recipe_ingredients') is not null
union all select '001', 'table public.meal_plans',
       to_regclass('public.meal_plans') is not null
union all select '001', 'table public.grocery_items',
       to_regclass('public.grocery_items') is not null
union all select '001', 'table public.meal_suggestions',
       to_regclass('public.meal_suggestions') is not null
union all select '001', 'table public.recipe_ratings',
       to_regclass('public.recipe_ratings') is not null
union all select '001', 'function is_household_member(uuid)',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'is_household_member')

-- ============ 002: recipe columns + recipe_ingredients ============
union all select '002', 'recipes.category',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'category')
union all select '002', 'recipes.servings',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'servings')
union all select '002', 'recipes.prep_time_minutes',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'prep_time_minutes')
union all select '002', 'recipes.cook_time_minutes',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'cook_time_minutes')
union all select '002', 'recipes.instructions',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'instructions')
union all select '002', 'recipes.is_favorite',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'is_favorite')
union all select '002', 'recipes.source_type',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'source_type')
union all select '002', 'recipes.source_detail',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'source_detail')
union all select '002', 'recipe_ingredients.sort_order',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipe_ingredients' and column_name = 'sort_order')

-- ============ 003: grocery_items (beta shape) ============
union all select '003', 'grocery_items.quantity',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'grocery_items' and column_name = 'quantity')
union all select '003', 'grocery_items.created_at',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'grocery_items' and column_name = 'created_at')
union all select '003', 'policy "Members can read grocery items"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'grocery_items' and policyname = 'Members can read grocery items')

-- ============ 004: meal_plans (beta shape) ============
union all select '004', 'meal_plans.created_at',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'meal_plans' and column_name = 'created_at')
union all select '004', 'policy "Members can read meal plans"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'meal_plans' and policyname = 'Members can read meal plans')

-- ============ 005: grocery_contributions ============
union all select '005', 'table public.grocery_contributions',
       to_regclass('public.grocery_contributions') is not null
union all select '005', 'index grocery_contributions_meal_plan_idx',
       to_regclass('public.grocery_contributions_meal_plan_idx') is not null
union all select '005', 'index grocery_contributions_grocery_item_idx',
       to_regclass('public.grocery_contributions_grocery_item_idx') is not null
union all select '005', 'policy "Members can read contributions"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'grocery_contributions' and policyname = 'Members can read contributions')

-- ============ 006: multi-meal (constraint REMOVALS — ok = absent) ============
union all select '006', 'constraint meal_plans_household_id_date_key ABSENT',
       not exists (select 1 from pg_constraint
                   where conname = 'meal_plans_household_id_date_key'
                     and conrelid = to_regclass('public.meal_plans'))
union all select '006', 'constraint meal_plans_household_id_date_meal_type_key ABSENT',
       not exists (select 1 from pg_constraint
                   where conname = 'meal_plans_household_id_date_meal_type_key'
                     and conrelid = to_regclass('public.meal_plans'))

-- ============ 007: recipe image columns (the known 42703 gap) ============
union all select '007', 'recipes.source_image_path',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'source_image_path')
union all select '007', 'recipes.homemade_image_path',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'homemade_image_path')

-- ============ 008: recipe notes ============
union all select '008', 'recipes.notes',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipes' and column_name = 'notes')

-- ============ 009: dedupe (DATA-ONLY, informational) ============
union all select '009', 'no duplicate (household, name) recipe groups [informational]',
       not exists (select 1 from public.recipes
                   group by household_id, lower(btrim(name)) having count(*) > 1)

-- ============ 011: hull check (auth/RLS/FK hardening) ============
union all select '011', 'function join_household_by_code(text)',
       exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
               where n.nspname = 'public' and p.proname = 'join_household_by_code')
union all select '011', 'constraint unique_household_member',
       exists (select 1 from pg_constraint
               where conname = 'unique_household_member'
                 and conrelid = to_regclass('public.household_members'))
union all select '011', 'policy "Owner can insert household"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'households' and policyname = 'Owner can insert household')
union all select '011', 'policy "Members and owner can read household"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'households' and policyname = 'Members and owner can read household')
union all select '011', 'policy "Anyone can read household by join code" ABSENT',
       not exists (select 1 from pg_policies where schemaname = 'public'
                   and tablename = 'households' and policyname = 'Anyone can read household by join code')
union all select '011', 'policy "Members can update their own membership"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'household_members' and policyname = 'Members can update their own membership')
union all select '011', 'policy "Users can update their own rating"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'recipe_ratings' and policyname = 'Users can update their own rating')
union all select '011', 'meal_plans.recipe_id FK is ON DELETE SET NULL',
       exists (select 1 from pg_constraint
               where conname = 'meal_plans_recipe_id_fkey'
                 and conrelid = to_regclass('public.meal_plans')
                 and confdeltype = 'n')
union all select '011', 'meal_plans.household_id FK is ON DELETE CASCADE',
       exists (select 1 from pg_constraint
               where conname = 'meal_plans_household_id_fkey'
                 and conrelid = to_regclass('public.meal_plans')
                 and confdeltype = 'c')
union all select '011', 'grocery_items.household_id FK is ON DELETE CASCADE',
       exists (select 1 from pg_constraint
               where conname = 'grocery_items_household_id_fkey'
                 and conrelid = to_regclass('public.grocery_items')
                 and confdeltype = 'c')

-- ============ 012: one owned household per user ============
union all select '012', 'unique index one_owned_household_per_user',
       to_regclass('public.one_owned_household_per_user') is not null

-- ============ 013: per-person meals ============
union all select '013', 'household_members.user_id is NULLABLE',
       coalesce((select is_nullable = 'YES' from information_schema.columns
                 where table_schema = 'public' and table_name = 'household_members'
                   and column_name = 'user_id'), false)
union all select '013', 'household_members.dietary_preferences',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'household_members'
                 and column_name = 'dietary_preferences')
union all select '013', 'index household_members_id_household_key',
       to_regclass('public.household_members_id_household_key') is not null
union all select '013', 'meal_plans.member_id',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'meal_plans' and column_name = 'member_id')
union all select '013', 'constraint meal_plans_member_same_household_fk',
       exists (select 1 from pg_constraint
               where conname = 'meal_plans_member_same_household_fk'
                 and conrelid = to_regclass('public.meal_plans'))
union all select '013', 'trigger detach_member_meals_trigger',
       exists (select 1 from pg_trigger
               where tgname = 'detach_member_meals_trigger'
                 and tgrelid = to_regclass('public.household_members'))

-- ============ 014: profile-member policies ============
union all select '014', 'policy "Members can add profile members"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'household_members' and policyname = 'Members can add profile members')
union all select '014', 'policy "Members can update profile members"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'household_members' and policyname = 'Members can update profile members')
union all select '014', 'policy "Members can remove profile members"',
       exists (select 1 from pg_policies where schemaname = 'public'
               and tablename = 'household_members' and policyname = 'Members can remove profile members')

-- ============ 015: note columns ============
union all select '015', 'recipe_ingredients.note',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'recipe_ingredients' and column_name = 'note')
union all select '015', 'grocery_items.note',
       exists (select 1 from information_schema.columns
               where table_schema = 'public' and table_name = 'grocery_items' and column_name = 'note')

) checks
order by ok, migration, object;
