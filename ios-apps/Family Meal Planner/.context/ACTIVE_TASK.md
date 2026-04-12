# ACTIVE_TASK.md — FluffyList

**Session Focus:** Supabase migration — scaffolding complete, ready for integration testing.

---

## Completed This Session
1. SQL schema with RLS policies for all 9 tables
2. Supabase Swift SPM dependency added and resolving
3. Service layer: SupabaseManager, AuthService, HouseholdService, RecipeService
4. Codable model structs for all Supabase tables
5. Sign in with Apple view
6. Household onboarding (create / join by code)
7. Recipe list, add recipe, household info views
8. Feature flag wiring in app entry point
9. Clean build verified

## Next Objective
**Create Supabase project and test end-to-end.**

### Steps
1. Go to supabase.com, create new project
2. Run `supabase/migrations/001_initial_schema.sql` in SQL editor
3. Configure Sign in with Apple:
   - Add Apple as auth provider in Supabase dashboard
   - May need Services ID from Apple Developer portal
4. Copy project URL and anon key into `Secrets.xcconfig`
5. Build and run on simulator or device
6. Test: sign in -> create household -> see join code -> add recipe
7. Test: second user joins by code, sees shared recipes

## Not In Scope
- Meal plan / grocery tabs on Supabase (placeholder only)
- Offline caching
- Realtime subscriptions
- Photo scan changes
- Removing old CloudKit code
- App Store submission
