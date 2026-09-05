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

### 2026-08-31 night — 112 uploaded; seasonal-v1 merged to main
- **Build 112 archived + uploaded from the MacBook** (real PROXY_KEY now in its Secrets.xcconfig; upload via Apple ID in Organizer). "Archive only from Home iMac" is RETIRED — MacBook and Home iMac can both archive.
- `seasonal-v1` merged into main after the 112 upload, per plan. Main now = per-person meals + seasonal suggestions v1 (unreleased). Next build number is 113.
- Calendar JSON got an honest read: cells spot-checked against real harvest timing, all sound; one quibble — muscadine is late-Aug/Sep, listed available in Southeast July.
- **Next:** fig icon polishing pass → drop 1024 PNG into asset catalog → device pass of seasonal (set region, check "In season now") → archive 113 → announcement email. Icon and seasonal launch TOGETHER as 113.

### 2026-09-01 — seasonal badge tightened + muscadine fix (Home iMac, autonomous)
- **Leaf badge rule tightened** per the device-pass review: `seasonalRecipeIDs` now uses `Score.earnsBadge` (≥1 PEAK hit, OR ≥2 hits total) instead of any-hit `isSeasonal`. Rationale: onion and garlic sit on most months' available lists, so a single available hit put a leaf on nearly every recipe and the badge meant nothing. **The "In season now" shelf is deliberately unchanged** — it still promotes any hit (`isSeasonal`) and its ranking handles weak matches; a new test pins that a single-available-hit recipe stays on the shelf but gets no leaf, while a single peak hit earns one.
- **Calendar correction:** muscadine removed from Southeast July `available` (real timing is late Aug/Sep; it remains peak in Aug/Sep). Only JSON change; no other cells touched.
- **Suite: 168 tests, 0 failures** (167 + 1 new `testBadgeNeedsPeakHitOrTwoHits`); sim build verified on iPhone 17. Build number untouched — next is 113.
- Remaining before 113: finish the seasonal device pass (re-check badges are now selective), then archive 113 with the fig icon.

### 2026-09-01 afternoon — three pre-113 polish items (Home iMac, autonomous)
- **1. Household dietary hints (EVERYONE selected):** `DietaryMatch.householdConflict(members:recipe:ingredientNames:)` checks every member; the hint names the FIRST affected member in household member order (stable day to day) and adds "+N" for the rest, even when they clash with different preferences: "MIGHT NOT BE VEGAN FOR MAYA +1 · BUTTER". Wired into BOTH pickers (RecipePickerSheet rows and DayPickerSheet under the chips) — item 1 said "the picker", both sheets share the hint pattern so consistency won. Per-member selection unchanged; no members → no hint (pre-Phase-3 rendering preserved).
- **2. Open-nights count fixed:** new pure `Models/WeekSummary.swift` owns `plannedCount`/`openCount` + both italic lines. Open = start-of-day(date) ≥ start-of-day(today) AND no household meal (via DayPlan grouping, so orphaned rows count as household, matching rendering). A future member-only day IS open (the household slot is what the line is about). "Every night is planned."/"The week is settled." now fire whenever openCount == 0 — i.e. they mean "nothing left that could be filled", kept the original copy. `hasOpenFutureDay` (copy-week gating) already used a today-or-later rule and was left alone.
- **3. Week view: tap = recipe detail, swipe = Replace/Remove.** The week body is now a plain `List` (swipe actions only exist on list rows) with one row PER MEAL LINE; the Press look is drawn by the rows (top rule + date column + "+" on a day's first line; 42pt clear spacer + 14pt member indent below; 14/6pt vertical padding for first/inner lines). Tap pushes `SupabaseRecipeDetailView` via `navigationDestination(item:)` on the recipe id. Swipe-left: Remove (destructive, nearest edge) then Replace (tinted fluffyInk2); `allowsFullSwipe: false` since Remove has no undo. Swipe hidden on past days and the "Nothing for everyone" placeholder.
- **Smallest-reasonable-choice decisions** (revisit freely):
  - **"Clear the Whole Day" placement:** Remove swipe on a MULTI-meal day raises the existing confirmation dialog (Remove Meal / Clear the Whole Day / Cancel — "Replace Meal" left the dialog for the swipe); on a single-meal day the swipe removes immediately, standard iOS. So clearing a whole day is: swipe any meal → Remove → Clear the Whole Day.
  - **Past meals are tappable** (navigate to detail — looking back is harmless and useful); they were fully disabled before. Grey styling kept; swipe actions still absent on past days.
  - **"MEAL NEEDS ATTENTION" rows** (plan row whose recipe is missing): tap goes straight to the Replace picker (nothing to show in detail); swipe Remove/Replace works as on any row.
  - **Hint format:** "+N" sits directly after the name, before the "· keyword" — one FluffyMetadataLine, one line.
- **Suite: 174 tests, 0 failures** (168 + 2 new in DietaryMatchTests for householdConflict/copy + 4 new WeekSummaryTests incl. the past-days regression and the member-only-day rule); sim build + launch verified on iPhone 17 (fresh install, process alive). Build number untouched — next is 113.
- **Not covered by tests:** the List conversion itself (visual). The device pass should eyeball: day-row spacing/rules vs the old ScrollView layout, swipe on member rows, dialog on multi-meal days, pull-to-refresh still working inside the List, and the empty-week + loading states (untouched ScrollViews).

### 2026-09-01 — seasonal + polish device pass PASSED; 113 archived
- Verified on Dad's iPhone: fig icon on home screen; dormant with no region; Mid-Atlantic region persists; "In season now" shelf in Choose a Recipe; thinned leaf badges; household-meal dietary hint names the affected member; open-nights count ignores past days; tap meal → recipe, swipe → Replace/Remove.
- Known cosmetic (post-113): after swipe-remove, the week view refetches and rows disappear for a beat. Fix = remove row locally with animation, refresh silently.
- Pre-existing data note: user library has duplicate "Whole30 Egg Roll in a Bowl" recipes (not a code issue).
- 113 = per-person meals + seasonal suggestions v1 + fig icon. This is the coordinated-rollout build; announcement email follows.
- 2026-09-02: Join-by-code VERIFIED with a second real Apple ID (Shannon joined the household). Long-parked unknown closed.

---

## 2026-09-03 — Week navigation (MacBook, autonomous, branch `week-nav` — NOT merged to main)

- **Week navigation CODE DONE on branch `week-nav`** (pushed to origin; merge after its device pass, per the task instruction not to merge). The week view can now show any week from 4 back to 2 forward of the current one: chevron arrows in a nav row under the masthead (disabled at the bounds) plus a horizontal swipe anywhere on the view; a "This week" text link appears between the arrows whenever the displayed week isn't the current one. **Suite: 181 tests, 0 failures** (174 + 6 `WeekNavigationTests` + 1 new `CopyWeekTests`); sim build + launch verified on iPhone 17 (fresh install, process alive — sign-in screen, so the visual pass is on-device).
- **New pure model `Models/WeekNavigation.swift`** (WeekSummary-style, injectable today/calendar): bounds are measured from the CURRENT week so the window never drifts; exposes `previousWeekStart`/`nextWeekStart` (nil at a bound — arrows and swipe both just "go if it exists"), `isPastWeek`, `copySourceWeekStart` (displayed − 7), and the masthead title per offset ("This Week", "Last Week", "Next Week", "In Two Weeks", "Two/Three/Four Weeks Ago").
- **Past weeks are read-only:** every write affordance is gone (the "+" and swipe actions were already day-gated; empty-day taps are now inert instead of toasting; "Copy last week" hidden; open-nights line hidden) and one quiet italic note stands in for the state line: "A week gone by — kept for the record." Meals stay tappable (recipe detail). A past EMPTY week renders its ruled PASSED rows, not the "wide open" planning state.
- **"Copy last week" operates on the displayed week** (source = displayed weekStart − 7) through the existing `copyPreviousWeek(weekStart:)` — on next week's page it copies from the current week; new CopyWeekTests case pins it.
- **Fetch correctness:** week changes refetch via the existing `fetchPlans` (no cache assumptions); `changeWeek` clears `plansByDate` (the rows belong to the week just left; keyed by date they'd render the new week as seven "Nothing planned" rows) and shows "Fetching your week…" via an `isChangingWeek` flag; the in-flight task is cancelled on further navigation and `reloadWeek` drops stale results. **`MealPlanService.fetchPlans` gained a MainActor-confined fetch-generation guard** so a slow older fetch can never overwrite a newer week's rows or flip isLoading/errorMessage under it.
- **Seasonal follows the displayed day:** `RecipePickerSheet` now takes `seasonalMonth` (defaults to the current month) and the week view passes the month of the day being planned — planning two weeks ahead across a month boundary uses that month's harvest cells. Open-nights/state lines already used displayed `weekDates` (WeekSummary), unchanged.
- **Smallest-reasonable-choice decisions** (revisit freely): masthead titles are named weeks (the dateline below already carries "WEEK OF SEP 14"); the week-swipe is a plain `.gesture` on the content group so the List's own gestures keep winning where they claim the drag (vertical scroll, and Remove/Replace row swipes — on planned rows of editable weeks the row swipe wins, which matches standard iOS; past weeks have no row swipes so the whole page swipes); tab re-entry keeps the displayed week (no snap-back); the current week's own past days keep their existing toast — only fully past weeks go quiet.
- **Not covered by tests (visual, for the device pass):** nav row look (chevron weight/spacing, disabled tertiary state, "This week" link), swipe feel vs. row swipes and scrolling, the past-week note and PASSED rows, loading line during fast arrow-mashing, seasonal shelf when planning into October (region set, displayed week crossing the month).
- 2026-09-03: week-nav merged to main (23aa1b1). Archived + uploaded; Xcode auto-bumped build to 115 (114 consumed by a stray upload). Project build number set to 115. Next build = 116.

---

## 2026-09-03 evening — remove-flicker fix + warning cleanup (MacBook, autonomous, branch `remove-flicker` — NOT merged to main)

- **The swipe-remove flicker is FIXED** (the "known cosmetic" from the 113 device pass) **on branch `remove-flicker`** (pushed; merge after a device look). Remove, Clear the Whole Day, AND Replace/add are now optimistic: the week map is edited locally FIRST — the row animates out (or swaps) with `withAnimation(.easeInOut 0.25)` before the server round trip — then a **quiet reconcile** re-reads the week with a new `fetchPlans(weekStart:quiet:)` mode that never touches isLoading (and suppresses errorMessage on a failed reconcile — local state already shows the confirmed result). No more full `reloadWeek` after mutations, so the rest of the week never redraws. On a failed server delete the snapshot restores the exact rows with the same animation and the existing error banner shows. No visual changes otherwise; Press styling untouched.
- **New service surface (MealPlanService):** `removeLocalPlan(_:dateISO:)` / `removeLocalDay(dateISO:)` (both return the date's previous rows for restore), `replaceLocalSlot(with:)` (swaps only its own (date, member) slot's rows), `restoreLocalPlans(_:dateISO:)`. Replace builds the local row from the id `addMealWithGroceries` returns — `MealPlanRow` gained an explicit memberwise init (its custom `init(from:)` had suppressed the synthesized one).
- **The week-nav fetch-generation guard still holds, and got stronger:** every local edit calls `invalidateInFlightFetches()` — bumps `fetchGeneration` so a fetch already in flight (pull-to-refresh, tab-entry reload) drops its pre-edit rows instead of resurrecting a removed row for a beat, and clears `isLoading` (the superseded fetch skips its own clear, and no newer fetch exists yet to do it — without this the loading line could stick on an empty week). Quiet reconciles participate in the same generation ordering, so week navigation still supersedes them.
- **Swift 6 warning cleanup:** `SeasonalMatch.tokens`/`singularize` are now `nonisolated` (pure string helpers; under the project's default MainActor isolation, passing them to `map` warned) and the `HouseholdService` join_code log line unwraps with `?? "none"`. Both verified gone on a forced recompile. **Pre-existing, left alone (test target, out of scope):** `GroceryUnwindTests.swift:241` has the same pattern — main-actor-isolated `readAll` passed to a nonisolated context; same one-word `nonisolated` fix when convenient.
- **New tests: `OptimisticEditTests` (3)** against the fake PostgREST backend: removal updates local state BEFORE the DB round-trip (row gone from `plansByDate` while the fake server still holds it, then the delete catches up and the quiet reconcile agrees without flipping isLoading); restore-after-failure puts back the EXACT rows for both single-meal and whole-day snapshots; `replaceLocalSlot` touches only its own slot (Maya's meal survives a household replace). **Suite: 184 tests, 0 failures** (181 + 3); sim build + launch verified on iPhone 17.
- **For the device pass (visual, untestable here):** the removal animation on single- and multi-meal days (incl. member rows), Clear the Whole Day collapsing all lines at once, Replace swapping in place under the isAssigning overlay, no flicker after any of the three, error-banner restore (hard to trigger against prod — airplane mode mid-swipe works), and pull-to-refresh racing a swipe-remove.
- 2026-09-03: remove-flicker merged (0fa935b), archived + uploaded as build 116 (Xcode auto-bump from 115). Project build number set to 116. Next build = 117.

---

## 2026-09-03 night — iPad phase 1: cookbook on a stand (MacBook, autonomous, branch `ipad-support` — NOT merged to main)

- **iPad phase 1 CODE DONE on branch `ipad-support`** (pushed; merge after the iPad device pass). Recipe Detail adapts to the REGULAR horizontal size class: taller photo (345pt vs 230) across the top, then the title over two ruled columns — ingredients fixed at 300pt on the left, method (with notes + source) on the right behind a vertical hairline (FluffyRule turned 90°), capped at 680pt (≈65 characters at the 21pt body — the line-measure rule) — the whole block capped at 1080pt and centered so 11" landscape doesn't stretch edge to edge. Press type scales UP, same faces: title 36→44, body 17→21, quantities 14→17, step numerals 28→34 in a 42pt column. The "Add to the week" filled button caps at 560pt centered on regular (a pane-wide persimmon bar is a banner, not a button). **The iPad destination needed no project change** — TARGETED_DEVICE_FAMILY was already "1,2" with all four iPad orientations declared; it had just never been exercised.
- **Everything is size-class driven** — `Models/RecipeDetailLayout.swift`, a WeekSummary-style pure struct holding every layout decision (columns, type scale, caps), keyed ONLY off `isRegular` (from `horizontalSizeClass == .regular`; nil ⇒ compact). No device checks anywhere, so an iPad slide-over at compact width correctly gets the phone layout. **The compact values ARE the phone's historical constants and a test pins each one** — if `testCompactValuesAreTheHistoricalPhoneConstants` ever fails, the iPhone rendering changed, which phase 1 forbids. The compact content branch is the old VStack verbatim.
- **Screen awake:** new `Utilities/ScreenAwake.swift` — a MainActor hold-counting keeper over `UIApplication.isIdleTimerDisabled` (injected setter, so the counting is unit-tested without UIKit). Recipe Detail begins a hold on appear and ends it on disappear; **nowhere else touches it** (phase 1 rule). Sheets presented over the screen don't fire onDisappear, so the hold survives the edit/day-picker sheets; hold-counting means stacked details can't fight; unbalanced ends clamp at zero. Decision: it's active on BOTH size classes (the spec said "on appear, restore on disappear"; recipes get propped against phone stands too) — flip to regular-only in the view if David prefers.
- **Sheets on regular:** the edit sheet and DayPickerSheet get `.presentationSizing(.page)` on iPadOS 18+ (`fluffyRegularSheetSizing`, private to the detail view — promote in phase 2); earlier iPadOS keeps the default form sheet (usable, just smaller). Compact is untouched (the modifier is a no-op there).
- **Task 2 done:** `GroceryUnwindTests` `readAll` is now `nonisolated` — the last Swift 6 concurrency warning; a clean-build grep shows zero compiler warnings in app + test targets.
- **New tests (8):** `RecipeDetailLayoutTests` (5 — column threshold is the regular size class; compact values are the historical phone constants; regular strictly scales up; step measure sits in the readable 60–80-character band; the content cap actually fits ingredients + rule + full step measure) and `ScreenAwakeTests` (3 — begin disables / end restores; nested holds apply once and restore on last end; unbalanced end clamps and doesn't poison the next begin). **Suite: 192 tests, 0 failures** (184 + 8).
- **Verified this session:** iPhone 17 sim — suite green, app installs + launches (process alive). iPad Pro 11" (M5) sim — installs + launches, renders in BOTH orientations (rotated via the Simulator Device menu; window screenshots confirm portrait and landscape relayout; note `simctl io screenshot` reports the unrotated panel buffer on this runtime — use the window, not the file dimensions). Only the sign-in screen was reachable (no account on the sims) — **Recipe Detail's actual two-column rendering is the device pass's job.**
- **iPad device-pass checklist (on `ipad-support`, iPad or iPad sim with a signed-in account):**
  1. Recipe Detail portrait (the stand orientation): photo across the top, ingredients left / method right, vertical rule between, type visibly larger than phone, step lines ≤ ~65ch.
  2. Rotate to landscape: block centers, columns hold, nothing stretches edge to edge; rotate back — no layout glitches.
  3. A long recipe (many ingredients + steps): both columns scroll as one page; ruled rows align; servings scaler still on the INGREDIENTS head line.
  4. Recipes without a photo / without instructions / without notes: no empty-column oddities (the rule may stand alone next to an empty method — check it reads as intentional).
  5. Screen stays awake: leave Recipe Detail open past the device auto-lock interval — no dim/lock; navigate away — device locks normally again. Sheets (edit, day picker) don't break the hold.
  6. Sheets on iPad: edit + "Add to the week" day picker present at a workable size (page-size on iPadOS 18+).
  7. iPhone spot-check: Recipe Detail renders EXACTLY as build 116 (the layout tests pin the constants, but eyeball one recipe).
  8. Everything else on iPad (week view, lists, grocery) is phase 2 — expect stretched phone layouts there; that's known and fine.
- 2026-09-04: ipad-support merged; iPad device pass passed (rotation, long recipe, screen-awake, sheets, iPhone unchanged). Uploaded as build 117; project set to 117. Next = 118. Screen-awake kept on for iPhone too.

---

## 2026-09-04 — Seasonal visibility (autonomous, branch `seasonal-visibility` — NOT merged to main)

- **Seasonal visibility CODE DONE on branch `seasonal-visibility`** (do not merge until its device pass, per the task instruction). Seasonal suggestions now appear BEFORE a day is picked, in two places; build number untouched (117 uploaded). **Suite: 200 tests, 0 failures** (192 + 8 new `SeasonalStripTests`); sim build with zero warnings; install + launch verified on iPhone 17 AND iPad Pro 11" sims (process alive; sign-in screen only — no account on sims).
- **1. Recipes tab shelf:** a collapsible "In season now" section at the top of the browse (after search + chips, above the hero), reusing the picker's exact computation (`SeasonalMatch.inSeasonNow`, cap 8, current month) and the picker's row content. The row content was extracted into **`Design/FluffyRecipeRowLabel.swift`** (name + leaf, category, "IN SEASON · …" match line) and the picker's `recipeRow` now composes it — the picker, the shelf, and the strip all draw the same rows. Shelf rows navigate to recipe detail and carry the tab's usual context menu. Collapse state lives in a session-scoped static (`SeasonalShelfSession.isCollapsed`) — survives view recreation, resets next launch on purpose. Hidden when dormant (region unset / no matches).
- **2. Empty-week seasonal strip:** the "wide open" state now shows up to four in-season recipes (ruled Press list under an "In season now" section head) above the three action links. Tapping one opens `RecipePickerSheet` for the **first open night** of the displayed week with the recipe **pinned in a new "Your pick" section** (chips stay first, per the settled seasonal-v1 ordering; the pick can also appear again in the shelf/All Recipes — nothing hidden). `MealPickerContext` and the sheet gained `preselectedRecipeID`. The strip never renders on past weeks (the wide-open state already doesn't; the model also returns no open night for one).
- **New pure model `Models/SeasonalStrip.swift`** (WeekSummary-style): `picks(...)` = the picker's ranking, deduplicated by normalized recipe name (repeat-import duplicates — the known "Egg Roll in a Bowl" condition — would read as a bug in a four-row strip), capped at 4, dormant exactly when the shelf is; `firstOpenNight(weekDates:today:)` = first displayed-week day ≥ start-of-day(today), nil on a fully past week.
- **Smallest-reasonable-choice decisions** (revisit freely):
  - The strip (and the picker it opens) uses the month of the **first open night**, not the week-start's month — the two surfaces then always agree on the harvest cell when a week straddles a month boundary. The Recipes-tab shelf uses the current month, as specified.
  - The Recipes-tab shelf shows only in the **default browse** (no search text, ALL tag, favorites off): its picks ignore the filters, and a shelf contradicting an active filter reads as broken.
  - Strip rows show a chevron (they open the picker), not the suggested-list "+" (which adds directly).
  - "Collapsed for the session" = a plain static, deliberately not @AppStorage — a new launch (maybe a new month) gets the expanded shelf back.
- **No new colors/fonts; no network calls** — both surfaces derive from `recipeService.recipes`/`ingredientsByRecipeID` already in memory. iPad phase 1 untouched (`RecipeDetailLayout` and its pinned tests unchanged); the new sections are size-class-agnostic like the rest of the pre-phase-2 screens.
- **For the device pass (visual, untestable here):** shelf collapse/expand animation + chevron state and that the choice sticks across tab switches; shelf hidden while searching/filtering; strip look on the wide-open week (rules, leaf, match lines); tap-through to the picker with "Your pick" on top and chips still first; confirm lands on the first open night; region unset hides both surfaces; quick iPhone/iPad spot-check that Recipe Detail is untouched.
- 2026-09-04: seasonal-visibility merged; device pass passed. Build 118. Next = 119. Queued: replace wide-open empty-week state with the standard 7-row layout + seasonal strip/Copy last week as footer; one-time region prompt with Use-my-location (state → region).

---

## 2026-09-04 later — empty-week retirement + region prompt (autonomous, branch `empty-week-and-region` — NOT merged to main)

- **Both queued items CODE DONE on branch `empty-week-and-region`** (do not merge until a device pass). Build number untouched (118 uploaded). **Suite: 212 tests, 0 failures** (200 + 6 `WeekFooterTests` + 6 `StateRegionMapTests`); zero compiler warnings; install + launch verified on iPhone 17 AND iPad Pro 11" sims (sign-in screen only).
- **1. The "wide open" empty-week state is GONE.** An empty week now renders exactly like any partially planned week: seven ruled day rows, every open slot tappable, nothing special-cased. Deleted with it: the frying-pan art + "Your week is wide open." copy, the standalone "Browse recipes"/"Add a custom meal" links (both reachable from day rows / the picker), the "Popular in your kitchen" suggested list, `isWeekEmpty`, `suggestedRecipes`, and the view's `showingAddRecipe` sheet.
- **The planning FOOTER replaces it** — below the day rows, above "Build the grocery list": the seasonal strip (unchanged rows, now drawing its own 22pt insets) + "Copy last week". **New pure `Models/WeekFooter.swift`** owns the visibility rule: footer shows iff any SLOT — household or member — is open on a today-or-later day of the displayed week, and the week isn't past. (First cut keyed off WeekSummary's open-NIGHT count, which hid the footer from per-person households with only member slots left; widened same day on David's instruction to the old `hasOpenFutureDay` breadth, with a test pinning the member-slot case.) Past weeks keep PASSED rows, no "+", no footer; the open-nights line is untouched.
- **2. One-time seasonal region prompt** — **new `Views/SeasonalRegionPrompt.swift`**. Wherever a seasonal surface would render but no region is set (Recipes-tab shelf slot, picker's "In season now" section, week-footer strip slot), a Press ruled card stands in: "Pick your growing region" + a Menu of the eight regions (writes the same `seasonalRegion` AppStorage as Settings, so all surfaces flip at once and the prompt never returns) + "Use my location" + "Not now". `inList: true` variant drops rules/insets for the picker sheet's List. **"Not now" persists across launches** (`seasonalRegionPromptDismissed` AppStorage — a card that reappears every morning is a nag) and leaves a one-line Menu link ("Pick your growing region") in the card's place on all three surfaces.
- **Location flow — new `Utilities/RegionLocator.swift`:** when-in-use request (system asks once), single `kCLLocationAccuracyReduced` fix, reverse-geocode, `StateRegionMap.region(forState:)`, save, card dismisses itself. Every failure (denied/restricted, no fix, geocoder error, non-US, unmapped state) returns nil → the card shows "Couldn't place you — pick a region instead." and keeps the manual menu + retry. Nothing stored beyond the chosen region. `INFOPLIST_KEY_NSLocationWhenInUseUsageDescription` added to both app configs (plain wording, verified in the built product).
- **Geocoding is MapKit's `MKReverseGeocodingRequest`, not CLGeocoder** — the deployment target is actually **iOS 26.2** (RULES/CLAUDE.md's "iOS 17+" is stale) and CLGeocoder is deprecated there (was 2 warnings). The new address API has no structured state field, so the state is parsed from `addressRepresentations.cityWithContext` ("Cupertino, CA" → "CA"); country gated on `region?.identifier == "US"`. StateRegionMap accepts codes AND full names either way.
- **New pure `Models/StateRegionMap.swift`** (50 states + DC): judgment calls pinned by tests — mountain states split by harvest character (MT/WY/CO → Plains, UT/NV → Southwest, ID → Pacific NW), AK → Pacific NW, and **Hawaii deliberately unmapped** (a tropical year fits none of the 8 cells; Hawaiians get the manual picker rather than confident nonsense).
- **For the device pass (visual/interactive, untestable here):** empty week renders 7 rows + footer (no wide-open art anywhere); footer hidden on past weeks and on a fully planned week; strip rows still open the picker with "Your pick"; region card look on all three surfaces (tab, picker sheet, week footer); "Use my location" full flow on a real device incl. the system prompt + a deny → manual fallback; "Not now" → one-liner persists across relaunch; picking a region anywhere flips all surfaces at once and the prompt never returns; iPhone/iPad Recipe Detail untouched.

---

## 2026-09-05 — photo-scan 401 diagnosed + model pin updated (MacBook, on `empty-week-and-region`)

- **The "Server error (401)" on photo-to-recipe scan was the PROXY, not Anthropic.** Diagnosis: the app never calls Supabase edge functions or Anthropic directly — scan goes `SupabaseAddRecipeView` → `RecipeImageExtractor` → `AnthropicClient` → `https://fluffylist-proxy.onrender.com/v1/messages` with `X-Proxy-Key`; the Anthropic key lives only in Render's `ANTHROPIC_API_KEY` env var. A probe (empty-body POST, auth checked before body, never reaches Anthropic) showed the proxy rejecting the MacBook's `PROXY_KEY`.
- **⚠️ PROXY_KEY must match between Render and every archiving machine; Render's copy drifted and was reset to the MacBook value on 2026-09-05.** If the Home iMac's `Secrets.xcconfig` holds a different value, sync it to the MacBook's before archiving there, or its builds will 401 again.
- **Retired model pin fixed:** `claude-sonnet-4-20250514` → `claude-sonnet-5` in `Services/API/AnthropicModels.swift` (live scan path) and `Services/ClaudeAPIService.swift` (legacy, zero callers — updated for consistency; removal candidate). No other hardcoded model strings in the project.
- Stale "PLACEHOLDER key" comment at the top of this machine's `Secrets.xcconfig` corrected (value untouched).
- 2026-09-05: empty-week-and-region archived as build 119 directly from the branch (device pass not done first — scan fix was urgent), then merged to main. Project set to 119. Next = 120. Empty-week footer, region prompt, and location flow still need a device pass on 119.
