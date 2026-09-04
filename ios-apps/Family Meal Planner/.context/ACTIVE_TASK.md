# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-04 — Claude Code, autonomous) **Seasonal visibility: suggestions before a day is picked**, on branch `seasonal-visibility` (NOT merged to main — merge after its device pass).

1. **Recipes tab:** collapsible "In season now" shelf at the top of the browse (default browse only — hidden while searching/filtering), reusing the picker's computation and rows via the extracted `Design/FluffyRecipeRowLabel.swift`; collapse remembered for the session (`SeasonalShelfSession` static — resets next launch by design).
2. **Empty-week strip:** up to four in-season recipes above the wide-open state's action links (Press ruled list), keyed to the month of the week's first open night. Tap opens `RecipePickerSheet` for that night with the recipe pinned in a new "Your pick" section (`preselectedRecipeID` on `MealPickerContext` + the sheet; chips stay first). Never shows on past weeks.
3. **New pure model `Models/SeasonalStrip.swift`:** picker-ranked picks deduped by normalized name + capped at 4; `firstOpenNight` = first displayed-week day ≥ today, nil on past weeks.

**Suite: 200 tests, 0 failures** (192 + 8 `SeasonalStripTests`: ranking/cap, name dedup + back-fill, dormancy, first-open-night incl. start-of-day and past-week nil). Zero compiler warnings. Launch verified on iPhone 17 + iPad Pro 11" sims (sign-in screen only — no account).

## Next up

1. **Device pass of seasonal visibility** (checklist in HANDOFF, 2026-09-04 entry), then merge `seasonal-visibility` to main.
2. **iPad phase 2** (when David says go): week view, recipe list, grocery list on regular width.
3. Announcement email for the 113/116 rollout.
4. Seasonal v1.5 (parked): seasonal produce list into the AI suggestion prompt.
5. Parked: Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
