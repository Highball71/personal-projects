# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-08-31 late evening — Claude Code on David's MacBook Air, autonomous) **Seasonal Suggestions v1 CODE DONE on branch `seasonal-v1`** — bundled 8-region × 12-month produce calendar, Settings region picker, keyword scoring, "In season now" section in the recipe picker, leaf badges. App code + tests only: no migrations, no meal_plans changes, no icon, build number untouched. **Suite: 167 tests, 0 failures** (154 + 13 new); sim build + launch verified on iPhone 17.

**⚠️ BRANCH RULE: `seasonal-v1` must NOT merge to main until build 112 is archived + uploaded.** main still holds the exact content of 112 (Phases 2+3), which has passed its device pass but has NOT been archived yet. Merge in a later session, after the upload.

## State after this session

- **Data:** `FluffyListBeta/Resources/SeasonalCalendar.json` — curated calendar, 8 US regions (northeast, mid_atlantic, southeast, midwest, plains, southwest, pacific_nw, california) × 12 months, each entry flagged peak or available. 96 cells, 12–36 items each (avg ~23); lowercase singular keywords; storage crops honestly listed as available; deep-winter cold-region cells may have an empty peak list. The JSON is the single source of truth — correct harvest timing there.
- **Models:** `SeasonalCalendar.swift` (USRegion enum — raw values are the JSON keys AND the stored setting, never rename; bundle loader that goes dormant instead of crashing on a bad resource) and `SeasonalMatch.swift` (word-boundary token matching with plural folding, peak=2 / available=1 scoring, `inSeasonNow` capped at 8, `seasonalRecipeIDs` for badges).
- **Settings:** one "Seasonal region" row in the Recipes group (Press label/value + menu picker, "Not set" default). Stored as `@AppStorage("seasonalRegion")` — a device setting, no DB column (v1 scope).
- **Recipe picker (RecipePickerSheet):** "In season now" section between the assignment chips and Surprise Me, best score first, cap 8, each row with a leaf and an "IN SEASON · TOMATO, BASIL" line; All Recipes stays complete (nothing hidden) with a small leaf on qualifying rows. Seasonal rows still show the selected person's dietary hint — the two compose.
- **Elsewhere:** leaf badge (leaf.fill, fluffyInk2 — same deep spruce as the favorite heart) on recipe-list rows and on the DayPickerSheet's recipe line.
- **Dormancy:** unset region ⇒ no section, no badges, zero UI change anywhere — verified by tests at the model layer and by the picker/list rendering paths (all seasonal UI is gated on non-empty results).
- **Tests: 167 passing, 0 failures** (154 + 13 new): `SeasonalCalendarTests` (4 — bundle load, all 96 cells present + non-empty, keyword hygiene + no dup within a cell, out-of-range month) and `SeasonalMatchTests` (9 — peak weight, ranking, zero-hit exclusion, cap 8, dormancy for unset region and missing calendar, word-boundary/plural matching, name matching without double counting, match-line copy).
- Decisions taken where the feature doc was silent are logged in HANDOFF (2026-08-31 Seasonal v1 entry).

## Next up

1. **Archive/upload build 112** (Phases 2+3) from the Home iMac (real PROXY_KEY + ASC key) — device pass already PASSED 2026-08-31 evening.
2. **After 112 is uploaded:** merge `seasonal-v1` to main, then a device pass for seasonal (set region, check section/badges/dormancy) before it ships in a later build.
3. Seasonal v1.5 (parked): pass the current period's produce list into the AI suggestion prompt. Decide after seeing real library sizes.
4. Parked: app icon (half fig — launches WITH per-person + seasonal as one coordinated rollout); join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
