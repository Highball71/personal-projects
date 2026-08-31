# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-08-31 — Claude Code on home iMac, autonomous) Per-person meals **Phase 3 CODE DONE**: slot semantics reworked to (date, member_id), assignment chips on every meal-add flow, per-person day rows in the week view, keyword dietary hints. Full suite green (**154 tests**, 137 + 17 new); sim build + launch verified on iPhone 17. No migrations touched (schema was already complete after 013 + 014); build number untouched (111 already uploaded).

## State after this session

- **MealPlanService slot rework:**
  - `MealSlotScope` (.wholeDay / .household / .member) + private `clearMealsWithGroceries(on:scope:)` core. `clearDayWithGroceries` keeps its "nuke the day" meaning (now removing multiple meals, unwinding groceries for ALL of them — the 110 regression stays fixed); new `clearSlotWithGroceries(on:memberID:)` is the member-scoped variant.
  - `addMeal` / `addMealWithGroceries` take `memberID: UUID? = nil`. The assign path clears ONLY its own slot: household assigns never touch member meals and vice versa. One meal per (day, person), enforced app-side as before.
  - `copyPreviousWeek` is per-slot: copies keep their assignment, skip rules apply per (day, member) — a filled Maya slot doesn't block the household copy on the same day — past days still skipped silently, tallies now count meals.
- **New models:** `DayPlan` (pure day-row grouping: household meals first, member meals in members-list order, unknown/orphaned member_id renders as household, recipe-less rows dropped) and `DietaryMatch` (keyword-only conflict matcher + hint copy "Might not be Nut-Free · almond").
- **UI:** `FluffyAssignmentChips` (Press underlined small-caps EVERYONE · MAYA · SAM, single-select). RecipePickerSheet and DayPickerSheet both grew the chip row + per-member dietary hint (flag, never block; hidden for EVERYONE). Week view day rows render household meal as primary line, member meals as indented lines with a small-caps name kicker; per-meal tap → Replace / Remove sheet ("Clear the Whole Day" appears when a day holds >1 meal); "+" on filled rows adds another person's meal; "Nothing for everyone · TAP TO ADD" placeholder when a day has only member meals. Toasts say "Added for Maya — Tuesday".
- **Tests: 154 passing, 0 failures** (137 + 17 new): `SlotSemanticsTests` (7 — scoped replace both directions, multi-meal clear-day grocery settle, member-delete trigger orphan rendering, DayPlan grouping), `CopyWeekTests` (4 — assignment preserved, per-slot skips, silent past skips, empty source), `DietaryMatchTests` (6). Fake PostgREST store learned the `is.null` filter and emulates the 013 member-delete trigger. Shared `TestFixtures.swift` added.
- Sim build + launch verified on iPhone 17 (boots to sign-in, Press intact).
- Decisions taken where the feature doc was silent are logged in HANDOFF (2026-08-31 Phase 3 entry).

## Next up

1. Device pass for Phase 3 against prod: add a meal for a profile member, copy a week with member meals, delete a member and confirm their meal shows as household.
2. Archive/upload build 112 with Phases 2+3 when David says go (home iMac — real PROXY_KEY + ASC key).
3. Parked: join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic; seasonal suggestions (parked separately, do not touch).
