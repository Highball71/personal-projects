-- Disposable local database only. Requires 001_initial_schema.sql and 020.
-- Storage's minimal test fixture models the policy surface, not its HTTP API.
\set ON_ERROR_STOP on
do $$ begin
  if current_setting('fluffylist.local_test', true) is distinct from 'enabled' then
    raise exception 'This test requires the disposable local storage fixture';
  end if;
end $$;
insert into auth.users(id) values ('10000000-0000-0000-0000-000000000001'), ('10000000-0000-0000-0000-000000000002');
insert into public.households(id, owner_id) values
('20000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001'),
('20000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000002');
insert into public.household_members(household_id,user_id) select id,owner_id from public.households;
insert into public.recipes(id,household_id,name) values
('30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','Test soup'),
('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001','Another recipe');
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
insert into storage.objects(bucket_id,name) values ('family-recipe-photos','20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/photo.jpg');
insert into public.recipe_family_photos(id,recipe_id,household_id,image_path,caption) values
('40000000-0000-0000-0000-000000000001','30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/photo.jpg','Dinner');
update public.recipe_family_photos set caption='Second attempt';
update public.recipes set family_cover_image_path='20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/photo.jpg' where id='30000000-0000-0000-0000-000000000001';
do $$ begin
  begin
    update public.recipe_family_photos set is_archived=true;
    raise exception 'FAIL: cover archived';
  exception when raise_exception then
    if sqlerrm not like 'Choose another cover%' then raise; end if;
  end;
  begin
    update public.recipes set family_cover_image_path='20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/photo.jpg' where id='30000000-0000-0000-0000-000000000002';
    raise exception 'FAIL: wrong recipe cover accepted';
  exception when raise_exception then
    if sqlerrm not like 'Choose an active%' then raise; end if;
  end;
  begin
    update public.recipe_family_photos set household_id='20000000-0000-0000-0000-000000000002';
    raise exception 'FAIL: metadata reassigned';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.recipe_family_photos;
    raise exception 'FAIL: history permanently deleted';
  exception when insufficient_privilege then null;
  end;
  delete from storage.objects where bucket_id='family-recipe-photos';
  if (select count(*) from storage.objects) <> 1 then raise exception 'FAIL: attached image deleted'; end if;
end $$;
update public.recipes set family_cover_image_path=null where id='30000000-0000-0000-0000-000000000001';
update public.recipe_family_photos set is_archived=true;
update public.recipe_family_photos set is_archived=false;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
do $$ begin
  if (select count(*) from public.recipe_family_photos) <> 0 then raise exception 'FAIL: other household metadata visible'; end if;
  if (select count(*) from storage.objects) <> 0 then raise exception 'FAIL: other household images visible'; end if;
  begin
    insert into storage.objects(bucket_id,name) values ('family-recipe-photos','20000000-0000-0000-0000-000000000001/intruder.jpg');
    raise exception 'FAIL: other household upload allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.recipe_family_photos(id,recipe_id,household_id,image_path) values
    (gen_random_uuid(),'30000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000002/30000000-0000-0000-0000-000000000001/forged.jpg');
    raise exception 'FAIL: photo attached to another household recipe';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
set role anon;
do $$ begin
  begin
    perform 1 from public.recipe_family_photos;
    raise exception 'FAIL: anonymous metadata access';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
do $$ begin
  if (select public from storage.buckets where id='family-recipe-photos') then raise exception 'FAIL: public photo bucket'; end if;
  if (select count(*) from public.recipe_family_photos) <> 1 then raise exception 'FAIL: history lost'; end if;
end $$;
select 'PASS: household isolation, private bucket, cover ownership, archive/restore, immutable metadata, orphan cleanup guard, anonymous denial' as result;
