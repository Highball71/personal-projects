-- dedupe_recipes_dry_run.sql
--
-- READ-ONLY analysis script. Does NOT modify any data.
-- Identifies duplicate recipe groups within each household, keyed on
-- (household_id, lower(btrim(name))), and shows which row would be
-- chosen as the canonical row by the planned cleanup migration.
--
-- Canonical pick rule (in order of preference):
--   1. Most recent created_at
--   2. Most ingredient rows (richer record)
--   3. Lowest UUID (deterministic tiebreaker)
--
-- Run this in the Supabase Dashboard SQL Editor and review the output
-- BEFORE running any destructive cleanup. If a non-canonical row in
-- any group has data you want to keep (better notes, more ingredients,
-- a recent edit), edit the canonical row to match BEFORE running the
-- destructive migration.

with normed as (
  select
    r.id,
    r.household_id,
    r.name,
    r.created_at,
    lower(btrim(r.name)) as norm,
    (select count(*) from recipe_ingredients ri where ri.recipe_id = r.id) as ingredient_count,
    (select count(*) from meal_plans mp where mp.recipe_id = r.id)         as meal_plan_refs
  from recipes r
),
ranked as (
  select
    n.*,
    row_number() over (
      partition by household_id, norm
      order by created_at desc, ingredient_count desc, id asc
    ) as rn,
    count(*) over (partition by household_id, norm) as group_size
  from normed n
)
select
  household_id,
  norm                                            as normalized_name,
  group_size,
  -- Canonical row (rn = 1 within its group)
  (array_agg(id           order by rn))[1]        as canonical_id,
  (array_agg(name         order by rn))[1]        as canonical_name,
  (array_agg(created_at   order by rn))[1]        as canonical_created_at,
  (array_agg(ingredient_count order by rn))[1]    as canonical_ingredient_count,
  -- All ids in the group, ordered by canonical-first
  array_agg(id           order by rn)             as ids_in_group,
  array_agg(name         order by rn)             as names_in_group,
  array_agg(created_at   order by rn)             as created_at_in_group,
  array_agg(ingredient_count order by rn)         as ingredient_counts_in_group,
  array_agg(meal_plan_refs   order by rn)         as meal_plan_refs_in_group,
  -- Total meal_plans rows that would need repointing
  sum(case when rn > 1 then meal_plan_refs else 0 end) as meal_plans_to_repoint
from ranked
where group_size > 1
group by household_id, norm
order by group_size desc, household_id, normalized_name;

-- Quick summary across the whole DB (one row).
select
  count(*)                              as duplicate_groups,
  sum(group_size - 1)                   as duplicate_rows_to_delete,
  sum(case when rn > 1 then 1 else 0 end) filter (where rn > 1) as _check_same_as_above,
  sum(case when rn > 1 then ingredient_count else 0 end) as ingredient_rows_to_delete_via_cascade,
  sum(case when rn > 1 then meal_plan_refs   else 0 end) as meal_plans_to_repoint_total
from (
  select
    r.id, r.household_id,
    lower(btrim(r.name)) as norm,
    (select count(*) from recipe_ingredients ri where ri.recipe_id = r.id) as ingredient_count,
    (select count(*) from meal_plans mp where mp.recipe_id = r.id)         as meal_plan_refs,
    row_number() over (
      partition by r.household_id, lower(btrim(r.name))
      order by r.created_at desc, (select count(*) from recipe_ingredients ri where ri.recipe_id = r.id) desc, r.id asc
    ) as rn,
    count(*) over (partition by r.household_id, lower(btrim(r.name))) as group_size
  from recipes r
) ranked
where group_size > 1;
