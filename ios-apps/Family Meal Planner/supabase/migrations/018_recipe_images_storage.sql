-- 018_recipe_images_storage.sql
-- Create the "recipe-images" storage bucket and its RLS policies.
--
-- Root cause (2026-09-24 dashboard check): the V2 project
-- (papuusfhtojthtnbsdvs) has NO storage buckets — the bucket was
-- created by hand in the V1 dashboard and never recreated after the
-- V1→V2 move, because no migration owned it. This migration is that
-- missing owner, so the bucket can never silently drift away again.
--
-- Layout (established in 007_recipe_images.sql):
--   {household_id}/{recipe_id}/source.jpg     card photo
--   {household_id}/{recipe_id}/homemade.jpg   "Made this?" photo
--
-- The bucket is PUBLIC: the app reads images through unauthenticated
-- /storage/v1/object/public/ URLs (SupabaseManager.publicStorageURL),
-- which bypass RLS by design. The storage.objects policies below
-- govern WRITES (and authenticated reads): every operation requires
-- the object's first path segment to be a household the caller
-- belongs to, via the existing security-definer
-- public.is_household_member(uuid). A non-UUID first segment fails
-- the cast, which errors the request — nothing mis-shaped gets in.
--
-- The app uploads with upsert: true (re-attaching overwrites
-- source.jpg / homemade.jpg in place). Under storage-api an upsert
-- needs BOTH the insert and the update policy, so both are defined.
--
-- Idempotent: the bucket insert is ON CONFLICT DO UPDATE, and each
-- policy is dropped before create (CREATE POLICY has no IF NOT
-- EXISTS). Safe to re-run in the dashboard SQL editor.

-- 1. The bucket. 5 MB limit (the app uploads ≤1200px JPEGs at 0.8
--    quality, typically well under 500 KB); image MIME types only —
--    the app sends image/jpeg, the rest future-proof phone formats.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'recipe-images',
  'recipe-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic']
)
on conflict (id) do update
  set public            = excluded.public,
      file_size_limit   = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- 2. Policies on storage.objects, all scoped to this bucket AND to
--    the caller's own household (first path segment).

drop policy if exists "Household members can read recipe images" on storage.objects;
create policy "Household members can read recipe images"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'recipe-images'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "Household members can upload recipe images" on storage.objects;
create policy "Household members can upload recipe images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'recipe-images'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "Household members can update recipe images" on storage.objects;
create policy "Household members can update recipe images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'recipe-images'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  )
  with check (
    bucket_id = 'recipe-images'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );

drop policy if exists "Household members can delete recipe images" on storage.objects;
create policy "Household members can delete recipe images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'recipe-images'
    and public.is_household_member(((storage.foldername(name))[1])::uuid)
  );
