-- Staged only. Apply through an explicitly authorized deployment.
-- Additive history: no recipe, source image, grocery or meal-plan rewrites.
create table if not exists public.recipe_family_photos (
  id uuid primary key,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  household_id uuid not null references public.households(id) on delete cascade,
  image_path text not null unique,
  caption text not null default '',
  created_at timestamptz not null default now(),
  check (length(caption) <= 2000),
  check (lower(split_part(image_path, '/', 1)) = household_id::text),
  check (lower(split_part(image_path, '/', 2)) = recipe_id::text)
);
create index if not exists recipe_family_photos_recipe on public.recipe_family_photos(recipe_id, created_at desc);
alter table public.recipe_family_photos enable row level security;
drop policy if exists "Read household cooking photos" on public.recipe_family_photos;
create policy "Read household cooking photos" on public.recipe_family_photos for select to authenticated
using (public.is_household_member(household_id));
drop policy if exists "Add household cooking photos" on public.recipe_family_photos;
create policy "Add household cooking photos" on public.recipe_family_photos for insert to authenticated
with check (public.is_household_member(household_id) and exists (
  select 1 from public.recipes r where r.id = recipe_id and r.household_id = recipe_family_photos.household_id
));
-- Private storage: only household members can retrieve or add cooking photos.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('family-recipe-photos', 'family-recipe-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;
drop policy if exists "Read family photo objects" on storage.objects;
create policy "Read family photo objects" on storage.objects for select to authenticated
using (bucket_id = 'family-recipe-photos' and public.is_household_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "Add family photo objects" on storage.objects;
create policy "Add family photo objects" on storage.objects for insert to authenticated
with check (bucket_id = 'family-recipe-photos' and public.is_household_member(((storage.foldername(name))[1])::uuid));
drop policy if exists "Clean up unattached family photo objects" on storage.objects;
create policy "Clean up unattached family photo objects" on storage.objects for delete to authenticated
using (bucket_id = 'family-recipe-photos' and public.is_household_member(((storage.foldername(name))[1])::uuid)
  and not exists (select 1 from public.recipe_family_photos p where p.image_path = name));
revoke all on public.recipe_family_photos from anon;
grant select, insert on public.recipe_family_photos to authenticated;
