# FluffyList / Family Meal Planner Codebase Map

## Top Level
- `Family Meal Planner/`: active iOS target. `Family_Meal_PlannerApp.swift` has `private let useSupabase = true`, so `FluffyListBeta/` is the live app path; legacy CloudKit/Core Data code remains present.
- `_disabled/`: old SwiftData/Core Data model files and an alternate app entry file kept out of the active target.
- `_backup/`: preserved copies of earlier `ContentView` and app entry implementations.
- `supabase/`: SQL migrations plus one duplicate-recipe dry-run script for the Supabase backend.
- `Family Meal PlannerTests/`: unit tests for parsers, dates, fractions, ingredients.

## Current V2 / Supabase Architecture
- `Family Meal Planner/Family_Meal_PlannerApp.swift`: app entry; selects Supabase path and injects all Supabase services as environment objects.
- `FluffyListBeta/Views/AppRootView.swift`: root auth/onboarding/household gate; main Supabase tab bar.
- `FluffyListBeta/Services/SupabaseManager.swift`: singleton `SupabaseClient`; reads `SUPABASE_URL` and `SUPABASE_ANON_KEY`; caches current user/household IDs; builds storage URLs.
- `FluffyListBeta/Services/AuthService.swift`: Sign in with Apple to Supabase Auth, session check, sign-out, first household membership lookup.
- `FluffyListBeta/Services/HouseholdService.swift`: create/join/load household and members through `households` and `household_members`.
- `FluffyListBeta/Services/RecipeService.swift`: recipe/ingredient CRUD, duplicate-name detection, recipe image upload/update/delete.
- `FluffyListBeta/Services/GroceryService.swift`: grocery CRUD, batch dedupe/merge, meal-plan contribution tracking/removal.
- `FluffyListBeta/Services/MealPlanService.swift`: older one-meal-per-day orchestration with groceries; comments say DB now permits multiple rows but this service still clears a day before insert.
- `FluffyListBeta/Services/PlannedMealService.swift`: newer multiple-meals-per-day service backed by `meal_plans`.
- `FluffyListBeta/Models/SupabaseModels.swift`: PostgREST row/insert DTOs for households, members, recipes, ingredients, meal plans, groceries, contributions.
- `FluffyListBeta/Models/PlannedMeal.swift`: domain/row/insert model for multi-meal planning.
- `FluffyListBeta/Views/*.swift`: Supabase UI screens: sign-in, household onboarding/info/setup, recipes, meal plan, grocery, settings, debug.
- `Services/API/*`, `Services/Import/*`, `Services/ClaudeAPIService.swift`: Anthropic/proxy and recipe extraction/import support shared by current recipe flows.

## Supabase Folder
- Migrations: `001_initial_schema.sql` through `010_planned_meals.sql`.
- Tables created/evolved: `households`, `household_members`, `recipes`, `recipe_ingredients`, `meal_plans`, `grocery_items`, `meal_suggestions`, `recipe_ratings`, `grocery_contributions`.
- Key constraints/FKs: UUID PKs; household cascades to household-scoped rows; `household_members` unique `(household_id,user_id)`; `households.join_code` unique; recipe deletes cascade ingredients and set `meal_plans.recipe_id` null; contribution rows cascade from grocery items/meal plans.
- RLS: all main tables enable RLS. Helper `is_household_member(h_id uuid)` checks `household_members` against `auth.uid()`. Policies generally allow household members CRUD; household insert requires `auth.uid() = owner_id`; members can insert themselves. `001` also has an unrestricted household SELECT policy for join-code lookup.
- Later migrations: add recipe columns/ingredients, flat groceries, meal plans, contribution indexes, remove meal-plan uniqueness, add recipe image paths and notes, destructive recipe dedupe, then multi-meal `meal_type`/`sort_order` plus `meal_plans_household_date_idx`.
- Script: `scripts/dedupe_recipes_dry_run.sql` reports duplicate recipe groups before running `009_dedupe_recipes.sql`.

## Household Creation Flow
- `AppRootView` routes signed-in users with `SupabaseManager.currentHouseholdID == nil` to `HouseholdOnboardingView`.
- `SignInView` starts Apple auth, then `AuthService` loads membership.
- Relevant signatures:
  - `func checkSession() async`
  - `func signInWithApple(credential: ASAuthorizationAppleIDCredential) async`
  - `private func loadHouseholdMembership(for userID: UUID) async`
  - `func createHousehold(name: String, memberDisplayName: String) async -> Bool`
  - `func joinHousehold(code: String, memberDisplayName: String) async -> Bool`
- Creation path: `HouseholdOnboardingView.createView` calls `householdService.createHousehold(...)`; service inserts `households`, inserts a head-cook `household_members` row, sets `SupabaseManager.currentHouseholdID`, then loads members.

## TODOs / Half-Finished Signals
- `HouseholdService.swift` has temporary debug delay and verbose debug prints around create/join writes.
- `PlannedMealDebugView.swift` and `SupabaseSettingsView.swift` expose a DEBUG-only PlannedMeal screen marked temporary/remove with Phase 3.
- `MealPlanService.swift` and `PlannedMealService.swift` overlap; one clears slots and handles groceries, the other supports true multi-meal rows with no grocery side effects.
- `007_recipe_images.sql` says `homemade_image_path` is reserved for Phase 2.
- Legacy CloudKit path remains active in source but disabled by feature flag.

## Not Enough Info To Assess
- Whether all migrations have actually been applied to the live Supabase project.
- Xcode target membership/build settings beyond source inspection.
- Runtime auth/storage bucket configuration and production RLS behavior.
- Current TestFlight/App Store state; `STATUS.md` appears older than the Supabase V2 code.
