# HANDOFF.md — FluffyList

**Read this first.** Concise current state. Detailed trail lives in `.context/STUDIO_LOG/` and `SESSION_LOG.md`.

Last updated: 2026-08-27 (per-person meals Phase 1 session, on-Mac)

---

## Where things stand

**"The Press" overhaul is DONE and LIVE.** Compiled, device-verified, fast-forwarded to main, and **build 110 was archived + uploaded 8/16** (commit `9fd8e64`); it reached TestFlight "Testing". Five external testers added; public link `https://testflight.apple.com/join/h6qxWgE1`. (Earlier revisions of this file said "NOT yet compiled" — that was stale; the post-merge session never pushed doc updates.)

**Tester feedback arrived** (Kristin, via Copy Me That habits) and was triaged 2026-08-27:
- **"Copy last week" — IMPLEMENTED this session, authored off-Mac, NEEDS BUILD + DEVICE PASS.** One commit touching `MealPlanService.swift` + `SupabaseMealPlanView.swift`. Rules David decided: days already planned are **kept** (never overwritten); past days skipped **silently**. All copies go through `addMealWithGroceries` so grocery contributions carry over. Verification checklist in ACTIVE_TASK.md.
- **Per-person meals — APPROVED, Phase 1 CODE DONE (2026-08-27).** David answered all four open decisions (Option 1 nullable user_id; groceries identical; one meal per (day, member); keyword dietary matching for v1) — stamped into `FEATURE_PER_PERSON_MEALS.md`. Phase 1 implemented: `supabase/migrations/013_member_meals.sql` (nullable user_id, dietary_preferences[], meal_plans.member_id, composite FK **ON DELETE NO ACTION** + member-delete cleanup trigger — deliberately NOT SET NULL, see doc) plus `MealPlanRow`/`MealPlanInsert` decode changes. Ships dark; sim build + all 125 tests pass.
- **⚠️ Migration 013 is NOT YET APPLIED to `papuusfhtojthtnbsdvs`.** The Supabase MCP + CLI on this machine are authenticated to a different account (only sees "Placatto"). David: re-auth the Supabase connector (or `supabase login` as the FluffyList account), then apply `013_member_meals.sql`. Until then the app is fully compatible with the un-migrated DB (member_id decode is tolerant; insert omits nil).
- Still untriaged from Kristin's list: pantry-scan recipe suggestions, community recipe section.

**NEXT BUILD NUMBER: 111.** (110 is uploaded and live on TestFlight.)

---

## Known issues / deferred (do not fix without a decision)

- **`RecipeService.uploadRecipeImage` 3x renderer-scale quirk:** card photos upload at ~3600px. Harmless; fix for consistency someday.
- **Legacy CoreData+CloudKit V1 sync stack** still initializes each launch ("Change Token Expired" log noise). Dead machinery; removal candidate.
- **POLISH items from the first-hour review remain by design** — dead settings toggles, "Step 1 of 3" indicator, raw onboarding errors. The **dietary-preferences unkept promise now has a design home**: `FEATURE_PER_PERSON_MEALS.md` (per-member prefs, phase 2).
- **Join-by-code household flow still untested with a second Apple ID.** Test before inviting anyone to a shared household.
- Copy-last-week toast reuses `toastOverlay`, whose success/warning icon check is a string match on "only plan meals" — informational copy-toasts show the checkmark. Cosmetic.
- Older loose ends from May: cascade-delete runtime check never run; R003 log mislabels the `one_owned_household_per_user` catch branch.

---

## Build pipeline (proven end-to-end)

- Archive: `xcodebuild archive -scheme "Family Meal Planner" -destination "generic/platform=iOS" -archivePath <path> -allowProvisioningUpdates` + API-key auth flags.
- Upload: `xcodebuild -exportArchive` with ExportOptions.plist (`method: app-store-connect`, `destination: upload`, team `A5DP57PZ7N`).
- App Store Connect API key `AuthKey_W2DSSJX5TY.p8` at `~/.appstoreconnect/private_keys/` on the **home iMac**; Issuer ID `fc1e95cb-d040-4676-a773-349e35abab67`. Highball71 team only.

## Project facts

- Supabase: `papuusfhtojthtnbsdvs` (active). Old `dbunenacikpeeplnltrz` should be paused/deleted (2-project free-plan limit).
- Repo: FluffyList at `personal-projects/ios-apps/Family Meal Planner/`; git index is in the **parent** `personal-projects` repo (stage paths accordingly).
- Bundle `com.highball71.fluffylist.beta`, team `A5DP57PZ7N`, device "Dad's iPhone" registered.
- `PROXY_KEY` is the one real secret — gitignored `Secrets.xcconfig`, never commit it.
- Housekeeping (not urgent): repo structure tangled (Fast No Slow files mixed in); keep `.context` current each session.
- **This machine's `Secrets.xcconfig` holds the template PLACEHOLDER key** (created 2026-08-27 so compile-only builds work; gitignored). AI features will fail at runtime here until the real `PROXY_KEY` is filled in.

---

## 2026-08-27 evening update (supersedes stale bullets above)

- Migration 013 **applied to production** and column-verified (dashboard SQL Editor). The earlier BLOCKED item is resolved. The claude.ai Supabase connector is still signed into the Placatto-only account.
- Copy-last-week **device-verified**; details in ACTIVE_TASK. Next build 111 should ship it together with the grocery-unwind fix.
- **Known bug shipping in 110:** meal removal strands grocery items — the ON DELETE CASCADE on grocery_contributions defeats clearDayWithGroceries' post-delete unwind. Diagnosis + fix plan in ACTIVE_TASK.
- Info.plist now forces light-only appearance (Press has no dark palette).
- Mac-1929: Secrets.xcconfig has real Supabase values, placeholder PROXY_KEY → archive from home iMac only.
- Old Supabase project `dbunenacikpeeplnltrz` is **paused**.

---

## 2026-08-28 update (grocery-unwind fix)

- **The grocery-unwind bug is FIXED** (the "Known bug shipping in 110" above). `clearDayWithGroceries` now snapshots `grocery_contributions` (`GroceryService.fetchContributions(forMealPlans:)`) BEFORE deleting the `meal_plans` rows, verifies the delete as before, then settles grocery quantities from the snapshot (`settleContributions(_:)`) for exactly the rows the server confirmed deleted — the RLS-safety delete-first verification is preserved, and the ON DELETE CASCADE can no longer erase the evidence before the unwind runs. If the snapshot itself fails, the delete is aborted with an error (better to leave the meal than strand un-settleable groceries). `removeContributions` (the `removeMeal` path) now shares the same settle core. No DB/migration changes.
- **Removal-path audit:** `removeMeal` was already unwind-first (correct); the dead `clearSlot(on:)` — zero callers, deleted meal_plans with no grocery unwind at all — was removed.
- **Regression tests:** new `GroceryUnwindTests.swift` runs the real services against an in-memory fake PostgREST backend (URLProtocol on URLSession.shared; emulates the cascade; blocks all real network). The main test was verified to FAIL against the pre-fix code and passes now. **Suite: 128 tests, 0 failures** (125 + 3 new).
- Update to the 8/27 line "Next build 111 should ship it together with the grocery-unwind fix": the fix is now in. **111 still needs archiving from the home iMac** (real PROXY_KEY + ASC key). Build number untouched here.
- Sim quirk on Mac-1929: iPhone 17 sim twice refused to launch the test host ("Application failed preflight checks") — stale app install; fixed with `xcrun simctl uninstall com.highball71.fluffylist.beta`.

---

## 2026-08-30 update

- Build 111 archived and uploaded to App Store Connect from the home iMac (10:34 AM). Ships copy-last-week + light-only appearance + grocery-unwind fix.
- Next: confirm 111 appears in TestFlight, then Phase 2 per-person meals when David says go.
