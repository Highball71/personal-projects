-- 007_recipe_images.sql
-- Add image path columns to recipes for Living Recipe Cards.
-- Both nullable — recipes work fine without images.
--
-- source_image_path: cookbook/source photo chosen by user
-- homemade_image_path: reserved for Phase 2 (household's own photo)
--
-- Paths point to Supabase Storage objects in the "recipe-images" bucket.
-- Convention: {household_id}/{recipe_id}/source.jpg
--             {household_id}/{recipe_id}/homemade.jpg (Phase 2)

alter table recipes add column if not exists source_image_path text;
alter table recipes add column if not exists homemade_image_path text;
