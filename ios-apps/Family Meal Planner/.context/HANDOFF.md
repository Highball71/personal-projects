# HANDOFF.md — FluffyList

## One-Paragraph Resume
FluffyList Beta (Build 92) is migrating from CloudKit to Supabase for household sharing. The Supabase scaffolding is in place: SQL schema with RLS, Swift service layer (Auth, Household, Recipe), Codable models, Sign in with Apple flow, household create/join by code, and a recipe list view — all compiling and wired into the app behind a feature flag (`useSupabase = true` in `Family_Meal_PlannerApp.swift`). The old CloudKit code is preserved but inactive. Next: create a Supabase project, plug in real URL/key, and test end-to-end.

---

## Current Status
- **Build:** 92 (TestFlight, live — still CloudKit; Supabase path not yet deployed)
- **Branch:** main
- **Bundle ID:** com.highball71.fluffylist.beta
- **Display Name:** FluffyList Beta
- **Feature Flag:** `useSupabase = true` in Family_Meal_PlannerApp.swift
- **Proxy:** https://fluffylist-proxy.onrender.com (for Claude Vision API, unchanged)

## Architecture
- **Source of truth:** Supabase (Postgres + RLS)
- **Auth:** Sign in with Apple via Supabase Auth
- **Sharing:** Join-code flow (6-char code per household)
- **Old CloudKit path:** Preserved behind `useSupabase = false`, not deleted

## What's Done (Supabase Migration)
- SQL schema: `supabase/migrations/001_initial_schema.sql` (9 tables + RLS)
- SPM dependency: `supabase-swift` v2.43.1 added
- Config: `Secrets.xcconfig` has `SUPABASE_URL` / `SUPABASE_ANON_KEY` placeholders
- Service layer: `SupabaseManager`, `AuthService`, `HouseholdService`, `RecipeService`
- Models: `SupabaseModels.swift` (Codable Row/Insert structs)
- Views: `SignInView`, `HouseholdOnboardingView`, `AppRootView`, `SupabaseRecipeListView`, `SupabaseAddRecipeView`, `HouseholdInfoView`
- Build: Compiles clean (iPhone 17 Pro Simulator)

## What's Not Done Yet
- Supabase project not created (no real URL/key)
- Sign in with Apple not configured in Supabase dashboard
- Meal plan and grocery views not yet on Supabase path (placeholders)
- No offline/local cache
- No realtime subscriptions
- Old CloudKit code not yet removed

## Critical Files (New)
- `Family_Meal_PlannerApp.swift` — feature flag + both paths
- `Services/Supabase/` — all Supabase services
- `Models/Supabase/SupabaseModels.swift` — Codable structs
- `Views/Auth/` — all auth/onboarding/Supabase views
- `supabase/migrations/001_initial_schema.sql` — database schema
- `.context/MIGRATION_PLAN.md` — full migration plan

## Next Steps (In Order)
1. Create Supabase project at supabase.com
2. Run `001_initial_schema.sql` in SQL editor
3. Enable Sign in with Apple in Supabase Auth settings
4. Add real URL + anon key to `Secrets.xcconfig`
5. Test sign-in -> create household -> add recipe end-to-end
6. Wire up meal plan and grocery tabs to Supabase
7. Remove old CloudKit code after Supabase is validated
