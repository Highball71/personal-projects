# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-08-28 — Claude Code on Mac-1929) Grocery-unwind bug FIXED with regression tests. Next: archive/upload build 111 from the home iMac.

## State after this session

- **Grocery-unwind bug FIXED.** The week view's removal path (`clearDayWithGroceries`) deleted `meal_plans` rows first, then queried `grocery_contributions` — but the ON DELETE CASCADE (migration 005) had already destroyed those rows, so the unwind found nothing and grocery items were stranded. Fix keeps the RLS-safety intent instead of just reordering:
  1. `GroceryService.fetchContributions(forMealPlans:)` — SNAPSHOTS the contribution rows before the delete; if the snapshot fails, the delete is aborted (meals stay intact rather than stranding groceries forever).
  2. Delete + verify unchanged (server-confirmed rows, slot re-read).
  3. `GroceryService.settleContributions(_:)` — settles grocery quantities from the snapshot, filtered to the rows the server confirmed deleted. `removeContributions(forMealPlan:)` (the `removeMeal` path) was refactored onto the same settle core and still works.
  - Audit of other removal paths: `removeMeal` was already unwind-first (fine); dead `clearSlot(on:)` (no callers, deleted meal_plans with NO grocery unwind at all) was removed. No other `meal_plans` delete sites exist.
  - **No DB/migration changes** — the cascade stays; the app adapts.
- **Regression tests added** (`Family Meal PlannerTests/GroceryUnwindTests.swift`): an in-memory fake PostgREST backend (URLProtocol on URLSession.shared — the session the Supabase SDK uses; no test traffic can reach prod) that emulates the ON DELETE CASCADE. Three tests: week-view removal settles items (verified FAILING pre-fix: flour stuck at 4 cups, butter stranded), removeMeal path still settles, snapshot failure aborts the delete. **Full suite: 128 tests, 0 failures** (was 125 + 3 new) on iPhone 17 sim.
  - Sim note: two runs hit "Application failed preflight checks" launching the test host — a stale app install on the iPhone 17 sim; `simctl uninstall com.highball71.fluffylist.beta` fixed it. Not a code issue.
- **Build number NOT bumped, nothing archived** — per plan, 111 gets archived from the home iMac (real PROXY_KEY + ASC key live there).

## Next up

1. **Archive/upload build 111 from the home iMac** — ships copy-last-week + light-mode + the grocery-unwind fix together. Test suite is green; device pass of the unwind fix (remove a meal, watch the grocery list settle) is a good pre-archive sanity check.
2. Per-person meals **Phase 2** (People screen, profile members, per-member dietary prefs, AppStorage migration) when David says go.
3. Parked: join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic; migration 013 FK/trigger spot-checks before Phase 3.
