-- Applied to FluffyList V2 on 2026-10-25 after isolated policy tests.
-- Book illustrations are not family cooking history.
alter table public.recipes add column if not exists cookbook_image_path text;
alter table public.recipes drop constraint if exists cookbook_photo_ownership;
alter table public.recipes add constraint cookbook_photo_ownership check (
  cookbook_image_path is null or (
    lower(split_part(cookbook_image_path, '/', 1)) = household_id::text and
    lower(split_part(cookbook_image_path, '/', 2)) = id::text and
    array_length(string_to_array(cookbook_image_path, '/'), 1) = 3
  )
);
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('cookbook-recipe-photos', 'cookbook-recipe-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;
drop policy if exists "Read household cookbook photos" on storage.objects;
create policy "Read household cookbook photos" on storage.objects for select to authenticated
using (bucket_id = 'cookbook-recipe-photos' and exists (
  select 1 from public.recipes r where lower(split_part(storage.objects.name, '/', 1)) = r.household_id::text
    and lower(split_part(storage.objects.name, '/', 2)) = r.id::text and public.is_household_member(r.household_id)
));
drop policy if exists "Add household cookbook photos" on storage.objects;
create policy "Add household cookbook photos" on storage.objects for insert to authenticated
with check (bucket_id = 'cookbook-recipe-photos' and exists (
  select 1 from public.recipes r where lower(split_part(storage.objects.name, '/', 1)) = r.household_id::text
    and lower(split_part(storage.objects.name, '/', 2)) = r.id::text and public.is_household_member(r.household_id)
));
drop policy if exists "Clean unattached cookbook photos" on storage.objects;
create policy "Clean unattached cookbook photos" on storage.objects for delete to authenticated
using (bucket_id = 'cookbook-recipe-photos' and exists (
  select 1 from public.recipes r where lower(split_part(storage.objects.name, '/', 1)) = r.household_id::text
    and lower(split_part(storage.objects.name, '/', 2)) = r.id::text and public.is_household_member(r.household_id)
) and not exists (select 1 from public.recipes r where r.cookbook_image_path = storage.objects.name));
