Root cause: household existence is represented only by `SupabaseManager.currentHouseholdID`, an in-memory optional set asynchronously after auth. `AppRootView.body` routes any signed-in user with `currentHouseholdID == nil` to `HouseholdOnboardingView`, and `HouseholdService.createHousehold` never re-checks whether the user already belongs to/owns a household before inserting.

Exact launch/sign-in path:
1. `Family_Meal_PlannerApp` uses the Supabase path and injects `SupabaseManager`, `AuthService`, and `HouseholdService` into `AppRootView`.
2. `AppRootView` first gates on local `@AppStorage("hasSeenOnboarding")`; before that flag, it shows `WelcomeSplashView` then `HouseholdSetupView`, which only saves local preferences.
3. Once onboarding is seen, `AppRootView.task` calls `AuthService.checkSession()`. Sign-in similarly calls `AuthService.signInWithApple`.
4. Both auth paths set `authService.isSignedIn = true`, call `SupabaseManager.shared.setCurrentUser(...)`, then await `loadHouseholdMembership(for:)`.
5. `loadHouseholdMembership` selects `.from("household_members").eq("user_id", userID).limit(1)`. If a row is returned, it calls `setCurrentHousehold(first.householdID)`.
6. If the root view sees signed-in + nil household, it shows `HouseholdOnboardingView`. The Create button calls `HouseholdService.createHousehold(name:memberDisplayName:)`.
7. `createHousehold` inserts into `households` with `owner_id = session.user.id`, then inserts into `household_members`, then sets `currentHouseholdID`.

Why a returning household user can see Create Household again:
`AuthService.checkSession()` sets `isSignedIn = true` before membership lookup completes. That creates a transient state where `AppRootView` can render `HouseholdOnboardingView` even for an existing member. If `loadHouseholdMembership` is slow, fails, is blocked by RLS/network, or decodes no rows, the nil state persists. Its catch block swallows the error and does not distinguish “no membership” from “lookup failed.” There is also no persisted household ID fallback.

Prevention today:
Client: none. `createHousehold` does no preflight membership/owner query and no idempotent create.
DB: none for “one household per owner/user.” `supabase/migrations/001_initial_schema.sql` has `households.owner_id` with no unique constraint. `household_members` has `unique(household_id, user_id)`, which only prevents the same user joining the same household twice, not joining/owning multiple households. RLS policy `"Authenticated users can create household"` allows any authenticated user to insert any number of households where `owner_id = auth.uid()`.

Product-owner questions before fixing:
- Is the product invariant exactly one household per user, or can future multi-household membership exist?
- If duplicates already exist, which household should survive and what data should merge?
- Should “owner” and “head cook” be equivalent, transferable, or independent?
- On membership lookup failure, should the app block with an error/retry instead of offering create/join?
