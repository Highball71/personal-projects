# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-03 night — Claude Code on MacBook, autonomous) **iPad phase 1: the "cookbook on a stand" Recipe Detail**, on branch `ipad-support` (NOT merged to main — merge after the iPad device pass). Session was interrupted mid-verification and resumed; all work landed.

1. **Recipe Detail on the regular width:** two ruled columns (ingredients 300pt left, method right behind a vertical hairline, capped at 680pt ≈ 65 characters), taller photo (345pt), Press type scaled up with the same faces (title 44, body 21, quantities 17, step numerals 34/42pt column), content block capped at 1080pt and centered, "Add to the week" button capped at 560pt. All decisions in the pure `Models/RecipeDetailLayout.swift`, keyed only off `horizontalSizeClass == .regular` — no device checks; the compact branch is the old phone VStack verbatim and its constants are pinned by tests. iPad destination needed no project change (device family was already "1,2", all four iPad orientations declared).
2. **Screen awake:** `Utilities/ScreenAwake.swift` — hold-counting keeper over the idle timer (injected setter, unit-tested); Recipe Detail begins on appear / ends on disappear, nowhere else. Active on both size classes (spec's plain reading; flip to regular-only if preferred).
3. **Sheets:** edit + day-picker sheets present page-size on iPadOS 18+ via `fluffyRegularSheetSizing` (no-op on compact and older iPadOS).
4. **Warning cleanup complete:** `GroceryUnwindTests.readAll` is `nonisolated` — zero compiler warnings left in app + test targets.

**Suite: 192 tests, 0 failures** (184 + 5 `RecipeDetailLayoutTests` + 3 `ScreenAwakeTests`). Verified: iPhone 17 sim launch; iPad Pro 11" (M5) launch + render in BOTH orientations (window screenshots; only the sign-in screen reachable — no account on sims).

## Next up

1. **iPad device pass** (checklist in HANDOFF, 2026-09-03 night entry): two-column detail portrait + landscape, long recipes, missing photo/instructions/notes, screen-awake past auto-lock, sheet sizes, iPhone unchanged spot-check. Then merge `ipad-support` to main.
2. **iPad phase 2** (when David says go): week view, recipe list, grocery list on regular width.
3. Announcement email for the 113/116 rollout.
4. Seasonal v1.5 (parked): seasonal produce list into the AI suggestion prompt.
5. Parked: Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
