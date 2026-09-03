# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-09-03 — Claude Code on MacBook, autonomous) **Week navigation for the Press week view**, on branch `week-nav` (NOT merged to main — merge after its device pass).

The week view now shows any week from 4 back to 2 forward of the current one:

- **Navigation:** chevron arrows in a row under the masthead (disabled at the bounds) + horizontal swipe on the week view; "This week" link between the arrows whenever the displayed week isn't the current one. Masthead title tracks the offset ("This Week" / "Last Week" / "Next Week" / "In Two Weeks" / "Two–Four Weeks Ago"); the dateline keeps "WEEK OF MMM D".
- **Past weeks are read-only:** writes disabled (inert empty-day taps, no "+", no row swipes, no Copy last week, no open-nights line) with the quiet italic note "A week gone by — kept for the record." in the state-line slot. Meals still tap through to recipe detail. A past empty week shows its ruled PASSED rows, not the "wide open" planning state.
- **Copy last week** operates on the displayed week (source = displayed weekStart − 7) via the existing `copyPreviousWeek(weekStart:)`; hidden on past weeks.
- **Fetching:** week changes refetch through `fetchPlans` (no cache assumptions); stale in-flight fetches are cancelled/dropped (view task cancellation + a fetch-generation guard in `MealPlanService.fetchPlans`), and `changeWeek` clears `plansByDate` so the loading line shows instead of a wrong-week "Nothing planned" flash.
- **Displayed-week correctness:** open-nights/state lines already keyed off displayed `weekDates`; the recipe picker now takes `seasonalMonth` (month of the day being planned) so the seasonal shelf and leaf badges follow the displayed week across month boundaries.

**New:** `Models/WeekNavigation.swift` (pure, injectable — bounds, gating, copy-source math, titles) + `WeekNavigationTests` (6) + a CopyWeekTests case pinning copy-into-next-week. **Suite: 181 tests, 0 failures**; sim build + launch verified on iPhone 17 (fresh install, process alive).

## Next up

1. **Device pass of week navigation** (on `week-nav`): arrows at both bounds; swipe left/right incl. how it coexists with row Remove/Replace swipes and vertical scroll; "This week" return link; past-week read-only note + PASSED rows + no toasts; Copy last week on the current AND next week's page; seasonal shelf month when planning into October; fast arrow-mashing (loading line, no wrong-week rows).
2. Merge `week-nav` to main after the pass.
3. Confirm 113 in TestFlight → announcement email (113 = per-person meals + seasonal v1 + fig icon + polish; week nav ships in a LATER build).
4. Seasonal v1.5 (parked): seasonal produce list into the AI suggestion prompt.
5. Parked: Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
