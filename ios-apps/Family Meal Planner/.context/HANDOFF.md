# HANDOFF.md — FluffyList

**Read this first.** Concise current state. Detailed trail lives in `.context/STUDIO_LOG/` and `SESSION_LOG.md`.

Last updated: 2026-08-16 (Press overhaul session)

---

## Where things stand

**NEW 2026-08-16 — "The Press" visual overhaul implemented on branch `press-overhaul`** (8 commits, presentation layer only — no service/model/state changes). Chosen direction from the design bundle; Full Bleed (1b) rejected. NOT yet compiled — authored off-Mac; run a build + device pass before merging to main or archiving. See ACTIVE_TASK.md for the verification checklist. Note: the design handoff referenced a `ROADMAP_2026.md` in `.context/` that does not exist in the repo; HANDOFF.md remains canonical.


**Build 1.0 (102) uploaded to App Store Connect on Aug 10** from commit `61de30b`, awaiting Apple processing. This is the first build carrying the weekend's tester-readiness fixes — all SHOWSTOPPER items from the first-hour review are fixed.

### Remaining human steps (App Store Connect website, not CLI)
1. Answer the export-compliance question if prompted.
2. Assign build 102 to the external TestFlight group.
3. Send the public link to 3–5 friend testers.

### Shipped this weekend (commits `c067a83`, `49632a7`, `61de30b`)
- First-hour tester-readiness review completed; all showstoppers fixed.
- Sign-in cancel no longer shows a raw ASAuthorization error.
- Scan uploads resized to max 1200px (renderer scale pinned to 1).
- Extraction overlay is cancellable with real task cancellation (URLSession request aborts).
- "The Alberts" placeholder de-personalized.
- New shared `FluffyErrorBanner`: fetch failures show banner+Retry instead of masquerading as empty states (verified on device via airplane-mode pull-to-refresh); write failures (add/remove meal, grocery toggles/deletes/clear, favorites, recipe delete) show a dismissable banner.

---

## Known issues / deferred (do not fix without a decision)

- **`RecipeService.uploadRecipeImage` 3x renderer-scale quirk:** card photos upload at ~3600px, not 1200. Harmless (storage only); fix for consistency someday.
- **Legacy CoreData+CloudKit V1 sync stack** still initializes on every launch, errors and resets ("Change Token Expired" noise in logs). Dead machinery; candidate for removal.
- **POLISH items from the first-hour review remain unfixed by design** — dead settings toggles, "Step 1 of 3" indicator, unkept dietary-preferences promise, raw onboarding errors. Revisit after tester feedback.
- **Join-by-code household flow still untested with a second Apple ID.** Does not gate solo friend testing; test before inviting anyone to a shared household.
- Older loose ends from May: cascade-delete runtime check (delete a recipe assigned to a calendar day) never run; R003 log still mislabels the `one_owned_household_per_user` catch branch as dead code.

---

## Build pipeline (new this session — proven end-to-end)

Command-line archive + upload works:
- Archive: `xcodebuild archive -scheme "Family Meal Planner" -destination "generic/platform=iOS" -archivePath <path> -allowProvisioningUpdates` + the API-key auth flags.
- Upload: `xcodebuild -exportArchive` with ExportOptions.plist (`method: app-store-connect`, `destination: upload`, team `A5DP57PZ7N`).
- App Store Connect API key `AuthKey_W2DSSJX5TY.p8` at `~/.appstoreconnect/private_keys/` on the home iMac; Issuer ID `fc1e95cb-d040-4676-a773-349e35abab67`. Highball71 team only (Placatto needs its own key from pureevilindustries).
- **NEXT BUILD NUMBER: use 110** (skips stale TestFlight history at 104; the project file had drifted from actual uploads).

---

## Project facts
- Supabase: `papuusfhtojthtnbsdvs` (active). Old `dbunenacikpeeplnltrz` should be paused/deleted.
- Repo: FluffyList at `personal-projects/ios-apps/Family Meal Planner/`; git index is in the **parent** `personal-projects` repo (stage paths accordingly).
- Bundle `com.highball71.fluffylist.beta`, team `A5DP57PZ7N`, device "Dad's iPhone" registered.
- `PROXY_KEY` is the one real secret — lives in gitignored `Secrets.xcconfig`, never commit it.
- Known housekeeping (not urgent): repo structure is tangled (Fast No Slow files mixed in); keep `.context` current each session.
