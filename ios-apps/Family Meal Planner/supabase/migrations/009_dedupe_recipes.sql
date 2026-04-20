-- 009_dedupe_recipes.sql
--
-- DESTRUCTIVE: collapses duplicate recipe rows within each household.
-- Two recipe rows are considered duplicates when they share
-- (household_id, lower(btrim(name))).
--
-- Run order:
--   1. supabase/scripts/dedupe_recipes_dry_run.sql  (review)
--   2. THIS FILE                                    (cleanup)
--   3. 010_recipes_unique_name.sql                  (prevention)
--
-- Steps inside the transaction:
--   1. Build a temp `dedupe_map(duplicate_id, canonical_id)` using the
--      same canonical-pick rule as the dry run:
--        most recent created_at,
--        then most ingredient rows,
--        then lowest UUID.
--   2. Repoint meal_plans.recipe_id from duplicate -> canonical.
--      Without this step, ON DELETE SET NULL on meal_plans.recipe_id
--      would orphan plan rows in step 3.
--   3. Delete the duplicate recipe rows. recipe_ingredients on those
--      rows cascade-delete via the existing FK.
--   4. Verify: zero duplicate groups remain. If verification fails the
--      DO block raises and the entire transaction rolls back.
--
-- Counts are emitted via RAISE NOTICE so they show up in the SQL
-- Editor's "Messages" / "Output" tab. Compare them against the dry
-- run's summary row before treating this as successful.
--
-- If anything looks wrong while reading this, change the final COMMIT
-- to ROLLBACK before clicking Run. Once COMMIT lands, recovery is via
-- the snapshot you took before starting.

begin;

-- ============================================================
-- 1. Build the canonical map.
-- ============================================================
create temp table dedupe_map (
  duplicate_id uuid primary key,
  canonical_id uuid not null,
  household_id uuid not null,
  norm         text not null
) on commit drop;

with normed as (
  select
    r.id,
    r.household_id,
    r.created_at,
    lower(btrim(r.name)) as norm,
    (select count(*) from recipe_ingredients ri where ri.recipe_id = r.id) as ingredient_count
  from recipes r
),
ranked as (
  select
    n.*,
    row_number() over (
      partition by household_id, norm
      order by created_at desc, ingredient_count desc, id asc
    ) as rn
  from normed n
),
canonicals as (
  select household_id, norm, id as canonical_id
  from ranked where rn = 1
)
insert into dedupe_map (duplicate_id, canonical_id, household_id, norm)
select r.id, c.canonical_id, r.household_id, r.norm
from ranked r
join canonicals c using (household_id, norm)
where r.rn > 1;

-- ============================================================
-- 2 + 3 + 4. Repoint, delete, verify — all inside one DO block so
-- we can capture row counts and abort on a verification failure.
-- ============================================================
do $$
declare
  planned_deletions  int;
  meal_plans_repointed int;
  recipes_deleted    int;
  remaining_groups   int;
  remaining_dup_rows int;
begin
  select count(*) into planned_deletions from dedupe_map;
  raise notice 'dedupe_map rows (planned deletions): %', planned_deletions;

  if planned_deletions = 0 then
    raise notice 'No duplicates found. Nothing to do.';
    return;
  end if;

  -- Repoint meal_plans.
  with repointed as (
    update meal_plans mp
    set recipe_id = dm.canonical_id
    from dedupe_map dm
    where mp.recipe_id = dm.duplicate_id
    returning mp.id
  )
  select count(*) into meal_plans_repointed from repointed;
  raise notice 'meal_plans repointed:                %', meal_plans_repointed;

  -- Delete duplicate recipes (recipe_ingredients cascade).
  with deleted as (
    delete from recipes r
    using dedupe_map dm
    where r.id = dm.duplicate_id
    returning r.id
  )
  select count(*) into recipes_deleted from deleted;
  raise notice 'recipes deleted this run:            %', recipes_deleted;

  -- Sanity: deletes should equal planned.
  if recipes_deleted <> planned_deletions then
    raise exception 'dedupe deletion count mismatch: planned %, deleted %. Rolling back.',
      planned_deletions, recipes_deleted;
  end if;

  -- Verify no duplicate groups remain.
  select count(*) into remaining_groups
  from (
    select 1
    from recipes
    group by household_id, lower(btrim(name))
    having count(*) > 1
  ) g;

  select coalesce(sum(c - 1), 0) into remaining_dup_rows
  from (
    select count(*) as c
    from recipes
    group by household_id, lower(btrim(name))
    having count(*) > 1
  ) g;

  raise notice 'duplicate groups remaining:          %', remaining_groups;
  raise notice 'duplicate rows remaining:            %', remaining_dup_rows;

  if remaining_groups <> 0 or remaining_dup_rows <> 0 then
    raise exception 'dedupe verification failed: % group(s), % row(s) still duplicated. Rolling back.',
      remaining_groups, remaining_dup_rows;
  end if;
end
$$;

-- If you want to abort instead, change the next line to:  rollback;
commit;
