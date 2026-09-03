# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-03 evening — Claude Code on MacBook, autonomous) **Remove-flicker fix + Swift 6 warning cleanup**, on branch `remove-flicker` (NOT merged to main — merge after a device look).

1. **Swipe-remove flicker fixed** (the "known cosmetic" from the 113 device pass). Remove, Clear the Whole Day, and Replace/add are optimistic: the local week map is edited first with a 0.25s easeInOut animation, the server write runs after, and a new **quiet** `fetchPlans(weekStart:quiet:)` mode reconciles without touching isLoading (or errorMessage on reconcile failure). No more full `reloadWeek` after mutations. A failed server delete restores the exact snapshot rows with the same animation + the existing error banner. New MealPlanService surface: `removeLocalPlan` / `removeLocalDay` / `replaceLocalSlot` / `restoreLocalPlans`; `MealPlanRow` gained an explicit memberwise init (Replace builds the local row from the id `addMealWithGroceries` returns).
2. **The week-nav fetch-generation guard still holds and got stronger:** every local edit bumps the generation (`invalidateInFlightFetches`) so an in-flight loud fetch drops its pre-edit rows instead of resurrecting a removed row, and clears the isLoading that superseded fetch would otherwise leave stuck.
3. **Warnings cleared:** `SeasonalMatch.tokens`/`singularize` marked `nonisolated` (pure string helpers under default MainActor isolation); `HouseholdService` join_code log unwraps with `?? "none"`. Pre-existing test-target warning left alone (out of scope): `GroceryUnwindTests.swift:241` — same pattern, `readAll` wants the same `nonisolated`.

**Suite: 184 tests, 0 failures** (181 + 3 new `OptimisticEditTests`: local-state-before-round-trip, exact restore for single-meal and whole-day snapshots, replace touches only its own slot); sim build + launch verified on iPhone 17 (process alive).

## Next up

1. **Device look at remove-flicker** (on `remove-flicker`): removal animation on single- and multi-meal days incl. member rows; Clear the Whole Day collapsing all lines; Replace swapping in place; no flicker after any mutation; error-banner restore (airplane mode mid-swipe); pull-to-refresh racing a swipe-remove. Then merge to main.
2. Announcement email for 113/115 rollout (per-person meals + seasonal v1 + fig icon + week nav).
3. Seasonal v1.5 (parked): seasonal produce list into the AI suggestion prompt.
4. Parked: Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic; GroceryUnwindTests readAll warning.
