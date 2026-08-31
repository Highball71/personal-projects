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

---

## 2026-08-31 update (per-person meals Phase 2, home iMac)

- **Phase 2 CODE DONE** (People screen, profile members, per-member dietary prefs, AppStorage migration). App code only — no migrations written or applied; build number untouched. **Suite: 137 tests, 0 failures** (128 + 9 new `MemberCRUDTests`); sim build + launch verified on iPhone 17. Details in ACTIVE_TASK.
- **⚠️ One deployment gap found — household_members RLS.** The policies in the repo (001 + 011) only permit INSERT/UPDATE/DELETE where `auth.uid() = user_id`, and NULL never matches, so **profile-member create/edit/delete will be RLS-blocked against prod** unless policies were added outside the repo when 013 was applied. Couldn't verify: this session's Supabase connector only sees the Placatto account. The app fails honestly (verified writes via `.select()` surface "couldn't be added/updated/removed" instead of silent success), and the dietary-prefs migration only touches the user's own row (covered by the existing "update own membership" policy), so nothing else breaks. **David: in the dashboard SQL editor on `papuusfhtojthtnbsdvs`, check then (if missing) run:**
  ```sql
  -- check what's there
  select policyname, cmd from pg_policies where tablename = 'household_members';

  -- profile-member policies (rows with user_id IS NULL, scoped to your own household)
  create policy "Members can add profile members" on public.household_members
    for insert to authenticated
    with check (user_id is null and public.is_household_member(household_id));
  create policy "Members can update profile members" on public.household_members
    for update to authenticated
    using (user_id is null and public.is_household_member(household_id))
    with check (user_id is null and public.is_household_member(household_id));
  create policy "Members can remove profile members" on public.household_members
    for delete to authenticated
    using (user_id is null and public.is_household_member(household_id));
  ```
  The `user_id is null` guard in WITH CHECK also stops anyone smuggling an account membership through these policies. Worth capturing as `014_profile_member_policies.sql` in the repo afterward (011-style drift capture) — not done this session per the no-migrations instruction.
- **Smallest-reasonable-choice decisions** (feature doc was ambiguous / impossible-as-written):
  - Onboarding dietary chips **still write the local AppStorage key** — the doc said they should write the member row instead, but that step runs before any account exists. The promise is kept transitively: `migrateLocalDietaryPreferencesIfNeeded()` (called from `loadCurrentHousehold`, which every entry path hits) promotes the key to the signed-in user's member row when that row's array is empty, then clears the key. Server wins over a stale local copy; failures keep the key and retry next launch.
  - **Editing model follows RLS reality:** you can edit yourself and profile members; other account members' rows are read-only in the UI (only they can edit, from their device). Delete exists only for profile members (confirmation dialog; the 013 trigger detaches their meals). Account members leave via their own device, as before.
  - PersonDetailView/AddPersonView are pushed screens with mastheads; the Settings "People" row lives in the Household group. Settings' device-level dietary declaration was removed (it was already unread).
- Refactors along the way: `DietaryOption` promoted to `Models/DietaryOption.swift` (**raw values are DB data now — never rename cases**); chips extracted to `Design/FluffyDietaryChips.swift` reusing `FluffyFlowLayout`; `HouseholdMemberRow.userID` is now `UUID?` with `isProfileMember`; fake PostgREST store supports PATCH representation + `seed()`.
- **Phase 2 boundary respected:** no slot-semantics rework, no assignment chips, no day-row changes, MealPlanService untouched. App icon + FEATURE_SEASONAL untouched (parked).

---

## 2026-08-31 later update (per-person meals Phase 3, home iMac, autonomous session)

- **Phase 3 CODE DONE on branch `phase3-slots`, merged to main** (suite green + sim launch verified per the session's safety rule). App code + tests only — no migrations (schema complete after 013/014), build number untouched (111 uploaded). **Suite: 154 tests, 0 failures** (137 + 17 new); sim build + launch verified on iPhone 17.
- **What changed:** slot key is now (date, member_id) — `MealSlotScope` + `clearSlotWithGroceries` member-scoped clear; `addMealWithGroceries(memberID:)` clears only its own slot; `copyPreviousWeek` copies per-slot with assignment intact; `DayPlan` (day-row grouping) + `DietaryMatch` (keyword hints) models; `FluffyAssignmentChips`; chips + hints in RecipePickerSheet AND DayPickerSheet; week-view day rows show household meal as primary line and member meals as indented kicker lines with per-meal Replace/Remove. Details in ACTIVE_TASK.
- **Protected behaviors, now with tests:** copy-last-week copies member meals with assignment, skips per (day, member) slot, skips past days silently (CopyWeekTests); clearDayWithGroceries removes ALL of a day's meals and settles groceries for every one — the 110 grocery-strand fix extended to multi-meal days (SlotSemanticsTests); member delete leaves meals as household meals via the 013 trigger, emulated in the fake store, and the UI grouping renders them that way.
- **Smallest-reasonable-choice decisions** (feature doc silent/ambiguous — revisit freely):
  - The day row's "+" opens the picker defaulting to EVERYONE while the household slot is open, otherwise to the first member without a meal that day. Assigning to a target that already has a meal that day REPLACES it (identical to Replace Meal — it's the same slot-clear write path); the chips make the target visible before the tap.
  - Member meal lines show the small-caps name kicker + recipe title only (no category/time metadata) to keep multi-meal rows compact; the household line keeps its metadata. Dynamic Type: lines wrap/lineLimit(2) as before.
  - A day with only member meals shows a tappable "Nothing for everyone · TAP TO ADD" household placeholder (future days only).
  - The per-meal action sheet offers "Clear the Whole Day" only when the day holds more than one meal — that's the surviving UI caller of clearDayWithGroceries; single-meal removal goes through removeMeal (unwind-first, per-row).
  - Dietary hints appear only when a specific person is selected (EVERYONE shows none), phrased honestly as a guess: "MIGHT NOT BE NUT-FREE · ALMOND". Bare "nut" is deliberately not a keyword (nutmeg); keyword lists live in DietaryMatch.
  - Copy-week tallies count meals (slots), not days; the existing toast copy still reads fine.
  - Legacy multi-row household slots and orphaned rows render EVERY row (nothing planned is invisible); they collapse on the next assign, as before.
- **Test infra:** fake PostgREST store now supports the `is.null` filter and emulates the 013 BEFORE DELETE trigger (household_members delete → meal_plans.member_id NULLed). New shared `TestFixtures.swift`. UUID columns come back uppercase from SDK inserts vs lowercase seeds — tests compare lowercased.
- **Untested against prod** (fake backend only): the composite-FK insert path with real member ids, and RLS behavior on member_id writes (no policy changes were needed per the feature doc, but no live write with member_id has happened yet). First device pass should add a member meal against `papuusfhtojthtnbsdvs`.

### 2026-08-31 — plane landed on Home iMac; resume from ANY machine
- All work is on origin/main at 42404dc (Phase 3). Nothing unpushed. Local `.claude/settings.local.json` shows modified on Home iMac — Claude Code's local permissions, harmless; if a future `git pull` complains about it, run `git checkout -- .claude/settings.local.json` first.
- **Next step: device pass of per-person meals** (checklist in ACTIVE_TASK). Can run from any machine whose `Secrets.xcconfig` has real SUPABASE_URL + SUPABASE_ANON_KEY (MacBook has them; office iMac — probe first, and check personal-projects is at ~/Developer). A placeholder PROXY_KEY only disables AI features; it does NOT block the device pass.
- **Archive 112 must happen on Home iMac** (only machine with real PROXY_KEY + ASC key). Do not archive until the device pass passes.
- Fresh session on any machine: `git pull --ff-only`, then open with the identity check (scutil --get ComputerName + pwd + branch + commit).

### 2026-08-31 evening — device pass PASSED (MacBook, wireless via hotspot)
- Per-person meals verified on Dad's iPhone against production: profile member CRUD (migration 014 proven live), assignment chips, dietary hints (warn-only confirmed), member-meal grocery contribution + unwind on remove, member delete → meal survives as household meal.
- Road to build 112 is OPEN. Archive from Home iMac (real PROXY_KEY + ASC key).
- Wireless debug note: hospital/public Wi-Fi blocks device discovery (client isolation); workaround = Mac joins iPhone's Personal Hotspot.

---

## 2026-08-31 late evening — Seasonal Suggestions v1 (MacBook, autonomous, branch `seasonal-v1`)

- **⚠️ READ THIS FIRST: all of this lives on branch `seasonal-v1`, pushed to origin. It must NOT merge to main until build 112 (Phases 2+3, currently the exact content of main) is archived + uploaded from the Home iMac.** The device pass for 112 already passed (see the entry above); only the archive/upload remains. Merge seasonal-v1 in a later session, after the upload.
- **Seasonal v1 CODE DONE**, built exactly to FEATURE_SEASONAL.md with its four settled decisions untouched: bundled JSON calendar (8 regions × 12 monthly periods, peak/available flags), one Settings region row, keyword-only scoring (peak weighted above available), "In season now" section (cap 8) in the recipe picker, leaf badges elsewhere. No migrations, no meal_plans changes, no icon work, build number untouched. **Suite: 167 tests, 0 failures** (154 + 13 new); sim build + launch verified on iPhone 17.
- **The calendar** (`FluffyListBeta/Resources/SeasonalCalendar.json`) is the heart: 96 cells, 12–36 keywords each (avg ~23), curated honestly — real harvest timing per region, storage crops (apple/roots/winter squash) listed as *available* through winter, and deep-winter cold-region cells allowed an EMPTY peak list rather than a padded one (a Northeast January has no peak harvest; tests only require peak+available combined non-empty). Keywords are lowercase singular ("tomato", "sweet corn", "mustard greens"). Correct timing mistakes in the JSON directly; tests enforce shape, not contents.
- **Smallest-reasonable-choice decisions** (feature doc silent — revisit freely):
  - **Region is a device setting** (`@AppStorage("seasonalRegion")`, USRegion raw value, "" = unset): v1 forbids DB changes, and the doc says "one setting is enough." A shared-household region can move to the households table in a later phase if it matters.
  - The Settings row sits in the **Recipes** group ("Seasonal region" / "Not set"), since it changes how recipes are surfaced.
  - **"In season now" sits after the "Who is this meal for?" chips** and before Surprise Me — the chips configure the pick and stay first; the seasonal section is the first *recipe* content. All Recipes stays complete below it (doc: promoted, never hidden), so a seasonal recipe appears in both.
  - **Matching is word-boundary token matching with plural folding, not raw substring** — stricter than DietaryMatch's `contains` on purpose: a false dietary hint is a gentle question, but a false "in season" promotion ("cornstarch" → corn) makes the feature look broken, and the doc warns sloppy matching is the main risk. "tomatoes" meets "tomato"; "mustard" does NOT meet "mustard greens". Known accepted looseness: "orange bell pepper" matches "orange", "plum tomatoes" matches "plum", "corn tortilla" matches "corn".
  - **Scoring:** peak hit = 2, available hit = 1 (each produce entry counts once even if hit in both name and ingredients); ties break on peak-hit count, then name. Section rows carry an "IN SEASON · TOMATO, BASIL" metadata line (max 3 names, peak first) in fluffyInk2.
  - **Leaf badge** = `leaf.fill` in fluffyInk2 (deep spruce — the same accent as the favorite heart, keeping Press's two-spot-colour discipline) on picker rows, recipe-list rows, and the DayPickerSheet recipe line. The recipe-list hero block is deliberately unbadged (its kicker line is already spoken for).
  - **A missing/malformed bundled calendar renders the feature dormant** (nil loader + empty results), never a crash.
- **Dormancy verified:** with no region set every seasonal computation returns empty and all seasonal UI is gated on non-empty results, so picker and recipe list render exactly as on main. Model-level dormancy is under test; visually confirmed at launch (fresh sim install has no region).
- **Composition with Phase 3 respected:** the seasonal section rows are the same shared row as All Recipes — assignment chips still drive the pick, and a seasonal row still shows the selected person's dietary hint (both hints can appear together).
- **New tests:** `SeasonalCalendarTests` (bundle load; all 8×12 cells present + non-empty; keyword hygiene incl. no peak/available dup within a cell; out-of-range month) and `SeasonalMatchTests` (weights, ranking, zero-hit exclusion, cap, dormancy ×2, word-boundary + plural matching, name matching without double counting, match-line copy). Fixtures reuse TestFixtures.recipeRow; a hand-built one-cell SeasonalCalendar keeps them independent of the real month.
- **Not done / later:** AI seasonal pairing is v1.5 per decision 4. Seasonal device pass happens after merge (post-112). Hemisphere-flip and non-US regions remain out of scope.
