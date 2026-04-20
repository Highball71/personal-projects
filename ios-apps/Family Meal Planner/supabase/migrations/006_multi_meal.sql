-- 006_multi_meal.sql
-- Allows multiple meal_plan rows per household + date.
-- The unique constraint enforced one meal per day — drop it
-- so users can plan breakfast, lunch, dinner, etc. on the same day.
--
-- The constraint may have been created by 001 (3-column) or 004 (2-column).
-- Drop both possible names for safety.

alter table meal_plans drop constraint if exists meal_plans_household_id_date_key;
alter table meal_plans drop constraint if exists meal_plans_household_id_date_meal_type_key;
