-- Run after the 020 local tests in a disposable database only.
\set ON_ERROR_STOP on
do $$ begin
  if current_setting('fluffylist.local_test', true) is distinct from 'enabled' then
    raise exception 'Disposable fixture required';
  end if;
end $$;
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',false);
insert into storage.objects(bucket_id,name) values ('cookbook-recipe-photos','20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/book.jpg');
update public.recipes set cookbook_image_path='20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/book.jpg' where id='30000000-0000-0000-0000-000000000001';
do $$ begin
  begin
    update public.recipes set cookbook_image_path='20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/book.jpg' where id='30000000-0000-0000-0000-000000000002';
    raise exception 'FAIL: borrowed another recipe image';
  exception when check_violation then null; end;
  delete from storage.objects where bucket_id='cookbook-recipe-photos';
  if (select count(*) from storage.objects where bucket_id='cookbook-recipe-photos') <> 1 then
    raise exception 'FAIL: attached book image removed';
  end if;
  if (select count(*) from public.recipe_family_photos) <> 1 then
    raise exception 'FAIL: family history changed';
  end if;
end $$;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',false);
do $$ begin
  if exists(select 1 from storage.objects where bucket_id='cookbook-recipe-photos') then
    raise exception 'FAIL: cross-household read';
  end if;
  begin
    insert into storage.objects(bucket_id,name) values ('cookbook-recipe-photos','20000000-0000-0000-0000-000000000001/30000000-0000-0000-0000-000000000001/intruder.jpg');
    raise exception 'FAIL: cross-household upload';
  exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
  if (select public from storage.buckets where id='cookbook-recipe-photos') then raise exception 'FAIL: public bucket'; end if;
end $$;
select 'PASS: private cookbook bucket, household isolation, recipe ownership, attached-object cleanup protection, family history unchanged' as result;
