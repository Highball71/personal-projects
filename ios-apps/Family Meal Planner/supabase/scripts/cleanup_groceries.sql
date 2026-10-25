-- Admin-only, one household, recoverable cleanup. NOT an app migration.
-- Replace HOUSEHOLD_ID, run with ROLLBACK first and inspect the report.
-- Only after verification replace the final ROLLBACK with COMMIT.
-- Read restore_groceries.sql before applying. Never remove the recovery record.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '20s';
select set_config('fluffylist.cleanup_household', 'HOUSEHOLD_ID', true);
-- Block writes for this short transaction, including FK cascades.
lock table public.meal_plans, public.grocery_items, public.grocery_contributions in share row exclusive mode;

create schema if not exists fluffylist_maintenance;
revoke all on schema fluffylist_maintenance from public, anon, authenticated;
create table if not exists fluffylist_maintenance.grocery_cleanup (
  id uuid primary key default gen_random_uuid(),
  household_id uuid not null,
  created_at timestamptz not null default now(),
  before_items jsonb not null,
  before_links jsonb not null,
  after_items jsonb,
  after_links jsonb,
  restored_at timestamptz
);
revoke all on fluffylist_maintenance.grocery_cleanup from public, anon, authenticated;
alter table fluffylist_maintenance.grocery_cleanup enable row level security;

create or replace function pg_temp.shopping_name(value text) returns text language sql immutable as $$
  select btrim(regexp_replace(value, '^\s*\[For\s+[^\]]+\]\s*', '', 'i'));
$$;
create or replace function pg_temp.shopping_key(value text) returns text language sql immutable as $$
  with normalized as (select lower(regexp_replace(btrim(value), '\s+', ' ', 'g')) as name)
  select case when name in ('extra-virgin olive oil','extra virgin olive oil','evoo')
    then 'olive oil' else name end from normalized;
$$;
create or replace function pg_temp.unit_key(value text) returns text language sql immutable as $$
  select case lower(btrim(value))
    when 'teaspoon' then 'tsp' when 'teaspoons' then 'tsp' when 'tsps' then 'tsp'
    when 'tablespoon' then 'tbsp' when 'tablespoons' then 'tbsp' when 'tbs' then 'tbsp'
    when 'cups' then 'cup'
    when 'fluid ounce' then 'fl oz' when 'fluid ounces' then 'fl oz' when 'floz' then 'fl oz'
    when 'ounce' then 'oz' when 'ounces' then 'oz'
    when 'pound' then 'lb' when 'pounds' then 'lb' when 'lbs' then 'lb'
    when 'gram' then 'g' when 'grams' then 'g'
    when 'kilogram' then 'kg' when 'kilograms' then 'kg'
    when 'milliliter' then 'ml' when 'milliliters' then 'ml'
    when 'liter' then 'l' when 'liters' then 'l'
    else lower(btrim(value)) end;
$$;
create or replace function pg_temp.unit_family(value text) returns text language sql immutable as $$
  select case when value in ('tsp','tbsp','fl oz','cup') then 'us-volume'
    when value in ('oz','lb') then 'us-weight'
    when value in ('g','kg') then 'metric-weight'
    when value in ('ml','l') then 'metric-volume'
    else 'unit:' || value end;
$$;
create or replace function pg_temp.unit_factor(value text) returns double precision language sql immutable as $$
  select case value when 'tbsp' then 3 when 'fl oz' then 6 when 'cup' then 48
    when 'lb' then 16 when 'kg' then 1000 when 'l' then 1000 else 1 end::double precision;
$$;

create temp table cleanup_before on commit drop as
select g.*, pg_temp.shopping_name(name) as cleaned_name,
  pg_temp.shopping_key(pg_temp.shopping_name(name)) as name_key,
  pg_temp.unit_family(pg_temp.unit_key(unit)) as unit_family,
  pg_temp.unit_factor(pg_temp.unit_key(unit)) as unit_factor,
  (not is_checked and (pg_temp.shopping_name(name) = '' or
     pg_temp.shopping_name(name) ~* '^For\s+the\s+[[:alpha:][:space:]&’''-]+:?$')) as heading
from public.grocery_items g
where household_id = current_setting('fluffylist.cleanup_household')::uuid;
alter table cleanup_before enable row level security;

do $$ begin
  if not exists(select 1 from cleanup_before) then raise exception 'No household grocery rows; refusing cleanup'; end if;
  if exists(select 1 from cleanup_before where quantity < 0 or quantity >= 'Infinity'::float8 or quantity = '-Infinity'::float8) then
    raise exception 'Invalid quantity requires manual review';
  end if;
end $$;

create temp table cleanup_links on commit drop as
select c.* from public.grocery_contributions c join cleanup_before b on b.id=c.grocery_item_id;
alter table cleanup_links enable row level security;
create temp table cleanup_run on commit drop as
with saved as (
  insert into fluffylist_maintenance.grocery_cleanup(household_id, before_items, before_links)
  select current_setting('fluffylist.cleanup_household')::uuid,
    (select jsonb_agg(to_jsonb(g) order by g.id) from public.grocery_items g join cleanup_before b on b.id=g.id),
    coalesce((select jsonb_agg(to_jsonb(c) order by c.id) from cleanup_links c), '[]'::jsonb)
  returning id
) select id from saved;
alter table cleanup_run enable row level security;

-- Nonempty notes may contain additional incompatible amounts or package sizes.
-- Keep those rows separate; never silently add quantities with different meanings.
create temp table cleanup_map on commit drop as
select b.id, first_value(b.id) over (
  partition by name_key, unit_family, case when coalesce(btrim(note),'') <> '' then id end
  order by created_at, id
) as keep_id
from cleanup_before b where not is_checked and not heading;
alter table cleanup_map enable row level security;

-- Move every original contribution ID before removing a redundant grocery row.
-- Convert contribution amounts to the surviving row's unit as well as totals.
update public.grocery_contributions c
set grocery_item_id = m.keep_id, quantity = c.quantity * (old.unit_factor / kept.unit_factor)
from cleanup_map m join cleanup_before old on old.id=m.id
join cleanup_before kept on kept.id=m.keep_id
where c.grocery_item_id=m.id and m.id<>m.keep_id;

update public.grocery_items g set quantity = totals.quantity
from (
  select m.keep_id, sum(b.quantity * (b.unit_factor / k.unit_factor)) as quantity
  from cleanup_map m join cleanup_before b on b.id=m.id
  join cleanup_before k on k.id=m.keep_id group by m.keep_id
) totals where g.id=totals.keep_id;

update public.grocery_items g set name=b.cleaned_name
from cleanup_before b where g.id=b.id and not b.is_checked and not b.heading and g.name<>b.cleaned_name;

delete from public.grocery_items g using cleanup_map m where g.id=m.id and m.id<>m.keep_id;
delete from public.grocery_items g using cleanup_before b where g.id=b.id and b.heading;

-- Verify each link survived, retaining its meal and its value in base units.
-- Only links to a removed section heading are intentionally retired.
do $$ begin
  if exists (
    select 1 from cleanup_links old join cleanup_before b on b.id=old.grocery_item_id
    left join public.grocery_contributions c on c.id=old.id
    left join public.grocery_items g on g.id=c.grocery_item_id
    where not b.heading and (c.id is null or c.meal_plan_id<>old.meal_plan_id
      or abs(c.quantity*pg_temp.unit_factor(pg_temp.unit_key(g.unit))-old.quantity*b.unit_factor)>0.00001)
  ) then raise exception 'Contribution preservation check failed'; end if;
  if exists (
    select 1 from cleanup_before b join public.grocery_items g on g.id=b.id
    where b.is_checked and to_jsonb(g)<>(select x from jsonb_array_elements(
      (select before_items from fluffylist_maintenance.grocery_cleanup where id=(select id from cleanup_run))) x where x->>'id'=b.id::text)
  ) then raise exception 'Checked item changed'; end if;
  if exists (
    select 1 from cleanup_map m join cleanup_before b on b.id=m.id
    join cleanup_before k on k.id=m.keep_id join public.grocery_items g on g.id=m.keep_id
    group by m.keep_id, g.quantity, k.unit_factor
    having abs(sum(b.quantity*b.unit_factor)-g.quantity*k.unit_factor)>0.00001
  ) then raise exception 'Grocery quantity preservation check failed'; end if;
end $$;

update fluffylist_maintenance.grocery_cleanup r set
  after_items=(select coalesce(jsonb_agg(to_jsonb(g) order by g.id),'[]'::jsonb) from public.grocery_items g where g.household_id=r.household_id),
  after_links=(select coalesce(jsonb_agg(to_jsonb(c) order by c.id),'[]'::jsonb) from public.grocery_contributions c join public.grocery_items g on g.id=c.grocery_item_id where g.household_id=r.household_id)
where r.id=(select id from cleanup_run);

select (select id from cleanup_run) as recovery_id,
  (select count(*) from cleanup_before) as original_rows,
  (select count(*) from cleanup_before where heading) as headings_removed,
  (select count(*) from cleanup_before where not is_checked and not heading and name<>cleaned_name) as section_labels_removed,
  (select count(*) from cleanup_map where id<>keep_id) as duplicate_rows_combined,
  (select count(*) from public.grocery_items where household_id=current_setting('fluffylist.cleanup_household')::uuid) as remaining_rows,
  (select count(*) from cleanup_links c join cleanup_before b on b.id=c.grocery_item_id where not b.heading) as preserved_meal_links,
  (select count(*) from cleanup_before where is_checked) as unchanged_checked_rows;
ROLLBACK;
