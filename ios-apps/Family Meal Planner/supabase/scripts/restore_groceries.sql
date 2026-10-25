-- Admin recovery companion for cleanup_groceries.sql.
-- Replace RECOVERY_ID with the reported run ID. Refuses to overwrite any
-- subsequent changes to the household's groceries or contribution links.
begin;
set local lock_timeout='5s';
set local statement_timeout='20s';
lock table public.meal_plans, public.grocery_items, public.grocery_contributions in share row exclusive mode;
do $$
declare r fluffylist_maintenance.grocery_cleanup%rowtype;
  current_items jsonb;
  current_links jsonb;
begin
  select * into strict r from fluffylist_maintenance.grocery_cleanup where id='RECOVERY_ID'::uuid for update;
  if r.restored_at is not null then raise exception 'Already restored'; end if;
  select coalesce(jsonb_agg(to_jsonb(g) order by g.id),'[]'::jsonb) into current_items from public.grocery_items g where household_id=r.household_id;
  select coalesce(jsonb_agg(to_jsonb(c) order by c.id),'[]'::jsonb) into current_links from public.grocery_contributions c join public.grocery_items g on g.id=c.grocery_item_id where g.household_id=r.household_id;
  if current_items is distinct from r.after_items or current_links is distinct from r.after_links then
    raise exception 'List changed since cleanup: recovery requires review; nothing restored';
  end if;
  delete from public.grocery_items where household_id=r.household_id;
  insert into public.grocery_items select * from jsonb_populate_recordset(null::public.grocery_items, r.before_items);
  insert into public.grocery_contributions select * from jsonb_populate_recordset(null::public.grocery_contributions, r.before_links);
  update fluffylist_maintenance.grocery_cleanup set restored_at=now() where id=r.id;
end $$;
commit;
