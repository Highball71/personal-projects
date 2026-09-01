# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-01 — Claude Code on Home iMac, autonomous) **Seasonal badge tightened + one calendar correction**, pre-113 tweaks from the seasonal review. The leaf badge now requires at least one PEAK hit OR at least two hits total (`Score.earnsBadge`, used only by `seasonalRecipeIDs`) — previously any single hit earned a leaf, and since onion/garlic sit on most months' available lists, nearly every recipe was badged. The "In season now" shelf is UNCHANGED (still promotes any hit; ranking handles weak matches). Calendar: muscadine removed from Southeast July available (it's late Aug/Sep). **Suite: 168 tests, 0 failures** (167 + 1 new badge-threshold test); sim build verified on iPhone 17. Build number untouched (next is 113).

**Prior session (2026-08-31 late evening, MacBook):** Seasonal Suggestions v1 CODE DONE — bundled 8-region × 12-month produce calendar, Settings region picker, keyword scoring, "In season now" section in the recipe picker, leaf badges. Merged to main after the 112 upload.

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
2. **Finish the seasonal device pass** (set region, check "In season now", verify badges are now selective, dormancy) — the badge fix from the first pass is in; re-check on device.
3. **Archive 113** (per-person + seasonal + fig icon) → announcement email.
4. Seasonal v1.5 (parked): pass the current period's produce list into the AI suggestion prompt. Decide after seeing real library sizes.
5. Parked: join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
