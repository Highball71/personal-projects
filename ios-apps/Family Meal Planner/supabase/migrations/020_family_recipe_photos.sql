-- Applied to FluffyList V2 on 2026-10-25 after isolated PostgreSQL policy tests.
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

-- Keep archived cooking photos recoverable. Never delete original scans.
alter table public.recipe_family_photos add column if not exists is_archived boolean not null default false;
alter table public.recipes add column if not exists family_cover_image_path text;

create or replace function public.validate_family_photo_cover() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.family_cover_image_path is not null then
    perform 1 from public.recipe_family_photos p
      where p.image_path = new.family_cover_image_path and p.recipe_id = new.id
        and p.household_id = new.household_id and not p.is_archived for update;
    if not found then raise exception 'Choose an active cooking photo from this recipe'; end if;
  end if;
  return new;
end;
$$;
drop trigger if exists validate_family_photo_cover on public.recipes;
create trigger validate_family_photo_cover before insert or update of family_cover_image_path on public.recipes
for each row execute function public.validate_family_photo_cover();

create or replace function public.protect_family_photo_cover() returns trigger
language plpgsql set search_path = public as $$
begin
  if new.is_archived and exists (select 1 from public.recipes r where r.family_cover_image_path = new.image_path) then
    raise exception 'Choose another cover or reset the cover before archiving this photo';
  end if;
  return new;
end;
$$;
drop trigger if exists protect_family_photo_cover on public.recipe_family_photos;
create trigger protect_family_photo_cover before update of is_archived on public.recipe_family_photos
for each row execute function public.protect_family_photo_cover();

drop policy if exists "Manage household cooking photos" on public.recipe_family_photos;
create policy "Manage household cooking photos" on public.recipe_family_photos for update to authenticated
using (public.is_household_member(household_id)) with check (public.is_household_member(household_id));
-- Only captions and archive state are editable, never household, path, or recipe.
revoke all on public.recipe_family_photos from authenticated;
grant select, insert on public.recipe_family_photos to authenticated;
grant update(caption, is_archived) on public.recipe_family_photos to authenticated;
