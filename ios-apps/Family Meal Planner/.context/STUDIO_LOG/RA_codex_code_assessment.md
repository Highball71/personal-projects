# Code & Architecture Assessment

FluffyList is improvable, but not safely agent-improvable yet. The repo contains a real app with a Supabase path selected in `Family Meal Planner/Family_Meal_PlannerApp.swift` (`useSupabase = true`), but the active path is lightly tested, mixed with legacy CloudKit code, and accepts untracked Swift files through Xcode file-system synchronized groups.

## 1. Tests

`Family Meal PlannerTests` has 125 unit tests across six files: `ExtractedRecipeTests.swift`, `JSONLDRecipeParserTests.swift`, `IngredientUnitTests.swift`, `ExtractedIngredientTests.swift`, `FractionFormatterTests.swift`, and `DateHelperTests.swift`. These are useful parser/formatter tests.

Real coverage of live Supabase code paths is near zero. There are no tests for `AuthService`, `HouseholdService`, `RecipeService`, `GroceryService`, `MealPlanService`, `PlannedMealService`, `SupabaseRecipeFormViewModel`, or the Supabase views. No mocked Supabase client, no repository protocol, no integration fixture, no UI test target. The shared scheme includes the test target, so `xcodebuild test` should be possible in principle, but there is no committed script, Makefile, CI, simulator destination, or smoke test that verifies the app works today.

## 2. Build Health

I did not run a build. Inspection shows several compile/runtime risks:

- The project uses `PBXFileSystemSynchronizedRootGroup`, so every Swift file under `Family Meal Planner/` and `Family Meal PlannerTests/` is likely build-visible. Untracked `PlannedMeal*.swift` files therefore matter.
- `Family_Meal_PlannerApp.swift` instantiates both legacy CloudKit services and Supabase services. Even with `useSupabase = true`, legacy types still need to compile.
- `SupabaseManager.swift` uses `fatalError` for missing `SUPABASE_URL` / `SUPABASE_ANON_KEY`; that is a launch-time crash, not a recoverable config failure.
- There is extensive `print` debug logging in `ClaudeAPIService.swift`, `AnthropicClient.swift`, `RecipeResponseParser.swift`, `HouseholdService.swift`, and `MealPlanningStore.swift`.
- `project.pbxproj.backup`, `_backup/`, `_disabled/`, and legacy code increase indexing/search noise, though `_backup` and `_disabled` are outside the synchronized app root.

No obvious duplicate top-level symbols jumped out inside the active root, but the untracked files make build status uncertain without `xcodebuild`.

## 3. MealPlan vs PlannedMeal

This is the sharpest current domain split. `MealPlanService.swift` and `MealPlanRow` model `meal_plans` as one recipe per date, with app-enforced replace semantics and grocery side effects. `PlannedMealService.swift`, `PlannedMeal.swift`, and `PlannedMealViewModel.swift` model the same `meal_plans` table as many meals per day, with `meal_type` and `sort_order`, and no grocery side effects.

Both are wired. The real tab UI uses `SupabaseMealPlanView` via `AppRootView`, and that view still uses `MealPlanService`. Recipe list/detail add-to-plan paths also use `MealPlanService`. `PlannedMeal` is wired only through `plannedMealService` environment injection and a temporary `PlannedMealDebugView` linked from `SupabaseSettingsView`. So `MealPlan` is production UI; `PlannedMeal` is a debug/transition path.

Risk: two services write/read the same table with incompatible invariants. One clears a date before insert; the other intentionally stacks rows. One handles grocery contributions; the other does not. An agent could easily “fix” one path and silently corrupt the other.

## 4. Dead Weight

Likely safe after one confirming build: `_backup/ContentView_*`, `_backup/Family_Meal_PlannerApp_ORIGINAL.swift`, `_disabled/old_models/*`, `_disabled/Family_Meal_PlannerApp_NEW.swift`, and `_disabled/FamilyMealPlanner.xcdatamodeld`. They are outside the app root.

Not safe to remove without intent: `Family Meal Planner/LegacyCloudKit/*`, `Services/MealPlanningStore.swift`, old `Views/*`, and old Core Data model classes. They still compile because `Family_Meal_PlannerApp.swift` keeps the CloudKit branch.

The deleted `../IntervalTimer/*` files are outside this app and should not be treated as FluffyList cleanup. The untracked `PlannedMeal*` files are build-visible and load-bearing for the settings debug row; remove only if also removing that environment object and navigation.

## 5. Design System

Heirloom is partially applied. Supabase screens such as `WelcomeSplashView.swift`, `HouseholdOnboardingView.swift`, `SupabaseMealPlanView.swift`, `SupabaseGroceryListView.swift`, and `SupabaseSettingsView.swift` use `Color+FluffyList` / `Font+FluffyList` heavily.

Inconsistent views include `AppRootView.swift` loading/retry states, `PlannedMealDebugView.swift`, and many legacy/non-Supabase views: `PhotoScanView.swift`, `AddEditRecipeView.swift`, `RecipeSearchView.swift`, `IngredientSearchView.swift`, `MealSlotView.swift`, `DayColumnView.swift`, `SettingsView.swift`, and `GroceryListView.swift`. Many use system fonts, `Color.accentColor`, `.orange`, or material styling.

## 6. Biggest Debt

The biggest debt is not styling or dead files; it is no testable boundary around the Supabase data layer. Services directly reach `SupabaseManager.shared.client` and `currentHouseholdID`, so business rules, RLS failure handling, date conversion, grocery side effects, and auth state are hard to verify without the live app.

## 7. Build First

First build a repeatable safety harness:

1. Add a committed headless command: `xcodebuild test -scheme "Family Meal Planner" -destination 'platform=iOS Simulator,name=iPhone 16'`.
2. Add CI that runs that command on every PR.
3. Introduce injectable protocols/fakes for Supabase access and household/auth state.
4. Add unit tests for `MealPlanService`/`PlannedMealService` invariants, date formatting, and grocery side effects.
5. Add one UI smoke test: launch with fake signed-in household, open Meals, Recipes, Grocery, Settings.
