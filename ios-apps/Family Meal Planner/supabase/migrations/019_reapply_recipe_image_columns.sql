-- 019_reapply_recipe_image_columns.sql
-- Re-apply 007_recipe_images.sql to FluffyList V2.
--
-- Root cause (2026-09-24 dashboard check): PATCHing
-- recipes.homemade_image_path on V2 (papuusfhtojthtnbsdvs) fails with
-- 42703 undefined_column — 007 was applied to V1 but never re-run
-- after the V1→V2 move. Reads never noticed because RecipeRow decodes
-- both paths with a try? fallback, and writes never noticed because
-- inserts omit nil keys and the upload failed first (no bucket, see
-- 018) so the path write was never reached.
--
-- Adds exactly what 007 adds, nothing more. Both nullable text —
-- recipes work fine without images. Idempotent (ADD COLUMN IF NOT
-- EXISTS), safe to re-run, and a no-op on a database where 007 did
-- run. Run alongside 018 (bucket + policies); verify with the SELECT
-- at the bottom.
--
-- Layout reminder (from 007): paths point into the "recipe-images"
-- bucket as {household_id}/{recipe_id}/source.jpg and /homemade.jpg.

alter table public.recipes add column if not exists source_image_path text;
alter table public.recipes add column if not exists homemade_image_path text;

-- verify: both rows should come back.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'recipes'
  and column_name in ('source_image_path', 'homemade_image_path')
order by column_name;
