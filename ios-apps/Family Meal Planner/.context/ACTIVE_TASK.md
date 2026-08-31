# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-08-31 — Claude Code on home iMac) Per-person meals **Phase 2 CODE DONE**: People screen, profile members, per-member dietary prefs, AppStorage migration. Full suite green (137 tests). One deployment step remains: the household_members profile-member RLS policies (SQL in HANDOFF) — verify/run in the Supabase dashboard before demoing profile-member add/edit/delete against prod.

## State after this session

- **Phase 2 implemented (app code only, no migrations touched):**
  - `PeopleView.swift` (new) — People screen (Settings → People): ruled member rows with dietary prefs as metadata, HEAD COOK / PROFILE tags; `PersonDetailView` (edit name + chips, remove profile members behind a confirmation dialog); `AddPersonView` (name on an ink rule + chips + filled button). All Press dress.
  - `HouseholdService` — `createProfileMember` / `updateMember` / `deleteProfileMember` (all verified with `.select()` so an RLS-blocked write reads as an honest error, never silent success) + `migrateLocalDietaryPreferencesIfNeeded()` hooked into `loadCurrentHousehold` (every path into the app lands there via SupabaseContentView's `.task`).
  - `HouseholdMemberRow` — `userID` now optional (NULL = profile member), `dietaryPreferences: [String]` added, tolerant decoder, `isProfileMember` helper. `HouseholdMemberInsert` — optional `userID` (nil omitted → column NULL), `dietaryPreferences` with `[]` default so old call sites are unchanged.
  - `DietaryOption` promoted to `Models/DietaryOption.swift` (was private in HouseholdSetupView; raw values are DB data now — never rename). Chip row extracted to `Design/FluffyDietaryChips.swift`, reusing the existing `FluffyFlowLayout` from SupabaseRecipeListView. HouseholdSetupView refactored onto both.
  - Settings: new "People" row in the Household group pushes PeopleView; the dead device-level `dietaryPreferences` @AppStorage declaration removed from Settings.
- **AppStorage → per-member migration rules** (doc'd choice): onboarding chips still write the local key (no account exists at that step); on first household load the key is promoted to the signed-in user's member row **iff the row's array is empty**, then cleared. Row already populated → server wins, stale local copy discarded. No member row / network failure → key kept, retried next launch.
- **Tests: 137 passing, 0 failures** (128 + 9 new in `MemberCRUDTests.swift`): profile-member create (NULL user_id, trimmed name, prefs stored), blank-name reject, update, delete, account-member delete refused, and 4 migration cases. Fake PostgREST store gained PATCH `return=representation` support and a `seed()` helper.
- Sim build + launch verified on iPhone 17 (boots to sign-in, Press intact). Build number untouched (111 already uploaded).

## Next up

1. **Run/verify the profile-member RLS policies** on `papuusfhtojthtnbsdvs` (SQL in HANDOFF 2026-08-31 entry — dashboard SQL editor, same as 013). Without them, profile-member add/edit/delete errors at runtime (own-row dietary migration works regardless). Then a quick device pass: add "Maya", set prefs, rename, remove.
2. Per-person meals **Phase 3** (slot semantics `(date, member_id)`, assignment chips, day-row rendering, dietary keyword flags in the picker) when David says go.
3. Parked: join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic; migration 013 FK/trigger spot-checks before Phase 3.
