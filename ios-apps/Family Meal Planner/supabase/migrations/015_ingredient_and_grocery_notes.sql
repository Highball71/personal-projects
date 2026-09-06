-- 015_ingredient_and_grocery_notes.sql
--
-- Nullable free-text note columns:
--
--   recipe_ingredients.note — a home for printed quantity text that
--   doesn't fit (quantity, unit): parenthetical package sizes
--   ("14 ounces"), quantity ranges ("1 1/4 to 1 1/2 lb"). Until now
--   this text was folded into the ingredient NAME, which polluted
--   grocery merging and search. The photo-import branch writes it
--   after its rebase onto this migration.
--
--   grocery_items.note — extra amounts that could not be merged
--   numerically into the row's (quantity, unit) because the units are
--   incompatible (e.g. a "1 piece" row receiving "2 tbsp"). The row
--   displays "1 piece + 2 tbsp" instead of splitting into two rows.
--
-- The app tolerates this migration being unapplied: both columns
-- decode as nil when absent, and inserts omit the key when the value
-- is nil. Writes with a NON-nil note fail until the migration is
-- applied, so apply it before the grocery-merge device pass.

alter table public.recipe_ingredients add column if not exists note text;
alter table public.grocery_items add column if not exists note text;
