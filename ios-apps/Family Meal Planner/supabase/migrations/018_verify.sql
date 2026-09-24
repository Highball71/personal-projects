-- 018_verify.sql
-- Read-only check after running 018_recipe_images_storage.sql in the
-- dashboard SQL editor. Expected:
--   1. One bucket row: recipe-images, public = true, 5242880,
--      {image/jpeg,image/png,image/webp,image/heic}.
--   2. Four "… recipe images" policies on storage.objects, one per
--      command (SELECT / INSERT / UPDATE / DELETE), role authenticated.

-- 1. The bucket row.
select id, name, public, file_size_limit, allowed_mime_types, created_at
from storage.buckets
where id = 'recipe-images';

-- 2. The final policy list on storage.objects.
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'storage' and tablename = 'objects'
order by policyname;
