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
