# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-01 — Claude Code on Home iMac, autonomous) **Three pre-113 polish items from today's device pass:**
1. **Household dietary hints:** with EVERYONE selected in either picker, the recipe is checked against every member's preferences; the hint names the first affected member in household order and counts the rest — "MIGHT NOT BE VEGAN FOR MAYA +1 · BUTTER" (`DietaryMatch.householdConflict` + new `hintText` overload; per-member behavior untouched; still warn-only).
2. **Open-nights bug fixed:** "One night is still open" no longer counts past empty days. New `Models/WeekSummary.swift` (pure, tested): open = today-or-later AND no household meal; a future member-only day still counts as open. `stateLine` + `openNightsLine` both use it; "settled"/"every night is planned" now mean "nothing left that could be filled".
3. **Week-view interaction rework:** TAP on any meal line (household or member) navigates to `SupabaseRecipeDetailView`; Replace + Remove are swipe-left actions per meal line. The week body became a plain `List` with one row PER MEAL LINE (swipe actions need list rows); the Press look is drawn by the rows themselves (rules, 42pt date column on the first line, cleared column below). "Clear the Whole Day" keeps its dialog placement — the Remove swipe raises the dialog on multi-meal days, removes directly on single-meal days. The "+" affordance is unchanged.

**Suite: 174 tests, 0 failures** (168 + 2 household-hint + 4 WeekSummary); sim build + launch verified on iPhone 17. Build number untouched (next is 113). Earlier today: seasonal leaf badge tightened (`Score.earnsBadge` = ≥1 peak or ≥2 hits; shelf unchanged) + muscadine removed from Southeast July.

## State after this session

- **Data:** `FluffyListBeta/Resources/SeasonalCalendar.json` — curated calendar, 8 US regions (northeast, mid_atlantic, southeast, midwest, plains, southwest, pacific_nw, california) × 12 months, each entry flagged peak or available. 96 cells, 12–36 items each (avg ~23); lowercase singular keywords; storage crops honestly listed as available; deep-winter cold-region cells may have an empty peak list. The JSON is the single source of truth — correct harvest timing there.
- **Models:** `SeasonalCalendar.swift` (USRegion enum — raw values are the JSON keys AND the stored setting, never rename; bundle loader that goes dormant instead of crashing on a bad resource) and `SeasonalMatch.swift` (word-boundary token matching with plural folding, peak=2 / available=1 scoring, `inSeasonNow` capped at 8, `seasonalRecipeIDs` for badges — badge rule is stricter than the shelf: `Score.earnsBadge` = ≥1 peak hit OR ≥2 hits total; the shelf keeps `isSeasonal` = any hit).
- **Settings:** one "Seasonal region" row in the Recipes group (Press label/value + menu picker, "Not set" default). Stored as `@AppStorage("seasonalRegion")` — a device setting, no DB column (v1 scope).
- **Recipe picker (RecipePickerSheet):** "In season now" section between the assignment chips and Surprise Me, best score first, cap 8, each row with a leaf and an "IN SEASON · TOMATO, BASIL" line; All Recipes stays complete (nothing hidden) with a small leaf on qualifying rows. Seasonal rows still show the selected person's dietary hint — the two compose.
- **Elsewhere:** leaf badge (leaf.fill, fluffyInk2 — same deep spruce as the favorite heart) on recipe-list rows and on the DayPickerSheet's recipe line.
- **Dormancy:** unset region ⇒ no section, no badges, zero UI change anywhere — verified by tests at the model layer and by the picker/list rendering paths (all seasonal UI is gated on non-empty results).
- **Tests: 168 passing, 0 failures**: `SeasonalCalendarTests` (4 — bundle load, all 96 cells present + non-empty, keyword hygiene + no dup within a cell, out-of-range month) and `SeasonalMatchTests` (10 — peak weight, ranking, zero-hit exclusion, badge threshold (single available hit ⇒ no leaf, single peak hit ⇒ leaf, two hits ⇒ leaf, shelf still promotes any hit), cap 8, dormancy for unset region and missing calendar, word-boundary/plural matching, name matching without double counting, match-line copy).
- Decisions taken where the feature doc was silent are logged in HANDOFF (2026-08-31 Seasonal v1 entry).

## Next up

1. ~~Archive/upload build 112~~ DONE 2026-08-31 night (from MacBook); `seasonal-v1` merged to main after.
2. **Device pass of today's three polish items** (household hints with EVERYONE, open-nights count late in the week, tap-to-detail + swipe Replace/Remove incl. member rows and the multi-meal Remove dialog) + re-check seasonal badges are now selective.
3. **Archive 113** (per-person + seasonal + fig icon + polish) → announcement email.
4. Seasonal v1.5 (parked): pass the current period's produce list into the AI suggestion prompt. Decide after seeing real library sizes.
5. Parked: join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
