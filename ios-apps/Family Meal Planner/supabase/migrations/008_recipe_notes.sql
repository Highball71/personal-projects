-- 008_recipe_notes.sql
-- Add the notes column to recipes. The app has been sending this field
-- in insert/update payloads, but the column was never created in the DB.
-- Reads worked because RecipeRow decodes with a try? fallback to "".

alter table recipes add column if not exists notes text not null default '';
