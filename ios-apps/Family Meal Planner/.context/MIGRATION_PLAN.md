# Migration Plan: CloudKit -> Supabase

## Why
CloudKit household sharing is unreliable — `CKShare` metadata version mismatches
cause "needs newer version" errors and there's no practical fix beyond
delete-and-recreate. Supabase gives us explicit control over sharing via
row-level security and a simple join-code flow.

## Architecture

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  SwiftUI     │────>│  Service Layer   │────>│  Supabase    │
│  Views       │<────│  (Swift async)   │<────│  (Postgres)  │
│              │     │                  │     │  + RLS       │
│  @State /    │     │  AuthService     │     │  + Auth      │
│  @Published  │     │  HouseholdService│     │  + Realtime  │
│              │     │  RecipeService   │     │              │
└──────────────┘     └──────────────────┘     └──────────────┘
```

### Source of truth
- **Supabase** is the source of truth for all shared data.
- No local Core Data cache in the first pass — direct Supabase reads.
- Offline support can be added later with a local SQLite mirror.

### Auth
- Sign in with Apple via Supabase Auth.
- Auto-create `profiles` row on signup (database trigger).

### Sharing model
- **Join code**: 6-character alphanumeric code per household.
- Creator gets a code, shares it out-of-band (text/verbal).
- Recipient enters code in app, becomes a `household_member`.
- No invite-link UX yet.

## Entity Mapping: Core Data -> Supabase

| Core Data Entity   | Supabase Table       | Notes                          |
|--------------------|----------------------|--------------------------------|
| CDHousehold        | households           | + join_code, created_by        |
| CDHouseholdMember  | household_members    | + profile_id (auth link)       |
| CDRecipe           | recipes              | + household_id FK              |
| CDIngredient       | recipe_ingredients   | + recipe_id FK                 |
| CDMealPlan         | meal_plans           | + household_id FK, unique slot |
| CDGroceryItem      | grocery_items        | + household_id FK              |
| CDMealSuggestion   | meal_suggestions     | + household_id FK              |
| CDRecipeRating     | recipe_ratings       | + rater_profile_id             |
| (none)             | profiles             | New — auth identity            |

## Service Layer

| Service            | Purpose                                    |
|--------------------|--------------------------------------------|
| SupabaseManager    | Singleton, holds Supabase client            |
| AuthService        | Sign in with Apple, session management      |
| HouseholdService   | Create/join/leave household, manage members |
| RecipeService      | CRUD recipes + ingredients                  |
| MealPlanService    | (future) Assign/clear meal slots            |
| GroceryService     | (future) CRUD grocery items                 |

## What Changes in the App

### Replace
- `PersistenceController` -> `SupabaseManager` (client lifecycle)
- `CloudKitSharingService` -> `HouseholdService` (join-code flow)
- `SyncMonitor` -> not needed initially (Supabase is always remote)
- `AppDelegate` share acceptance -> not needed (join-code instead)

### Keep (unchanged)
- `ClaudeAPIService` / `AnthropicClient` (recipe extraction)
- `RecipeSearchService` (web search)
- `KeychainHelper` (API key storage)
- `CameraPermissionService` (camera access)
- `MealPlanningStore` (will be adapted later)

### Keep (isolate, remove later)
- All old Core Data / CloudKit code stays in place.
- New Supabase path runs alongside; old path is not called.
- Delete old code once Supabase vertical slice works end-to-end.

## Session Deliverables

1. [x] SQL schema with RLS (`supabase/migrations/001_initial_schema.sql`)
2. [ ] Supabase Swift dependency added to Xcode project
3. [ ] `SupabaseManager.swift` — client singleton + config
4. [ ] `AuthService.swift` — Sign in with Apple
5. [ ] `HouseholdService.swift` — create/join household
6. [ ] `RecipeService.swift` — fetch/add recipes
7. [ ] Supabase model structs (Codable, not Core Data)
8. [ ] Auth gate view (sign in before main tabs)
9. [ ] Household onboarding view (create or join)
10. [ ] Wire into existing TabView

## What's NOT in Scope

- Offline/local cache
- Realtime subscriptions
- Invite-link deep links
- Photo scan changes
- iPad layout
- App Store submission
