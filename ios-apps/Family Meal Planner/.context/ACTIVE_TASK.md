# ACTIVE_TASK.md — FluffyList

**Session Focus:** Tester-feedback wave 1 — "Copy last week" implemented (needs Mac verification); per-person meals designed.

---

## Completed This Session (August 27, 2026 — chat session, off-Mac)

0. **Verified repo state before acting** (probe, not prose): press-overhaul was already merged and build 110 already on TestFlight — the session brief's "item 1" was stale. HANDOFF corrected; next build is **111**.
1. **Copy last week** — commit on top of `main` (`9fd8e64`):
   - `MealPlanService`: `copyPreviousWeek(weekStart:recipeService:groceryService:)` + `fetchWeekRows` helper + `CopyWeekResult` tally. Reads both weeks fresh from DB; collapses legacy multi-row slots (first row, view convention); copies via `addMealWithGroceries` only onto confirmed-empty slots, so its clear-first step is a no-op and contributions carry over.
   - **Rules (David, 2026-08-27): skip filled days (keep existing); skip past days silently** (pre-filtered so the write path's past-date guard never raises).
   - View: "Copy last week" `FluffyTextLink` in the week footer (shown only when an open, non-past day exists) and in the empty-week link stack. Assigning overlay text parameterized ("Copying last week..."). Press-voice toasts ("Copied three dinners from last week." / "…kept the days you'd planned." / "Last week was empty.").
2. **Per-person meals design** → `FEATURE_PER_PERSON_MEALS.md`. Nullable `member_id` on meal_plans (NULL = household), composite-FK tenant safety + member-delete trigger, no RLS policy changes, per-member `dietary_preferences` keeping the onboarding promise, Press UI (chip row, kicker day rows), 3-phase rollout, 4 open decisions awaiting David.

## Verification checklist (on a Mac, before archiving 111)

1. `git am` the session patch from the `personal-projects` root (or pull if already pushed), build for device.
2. Copy-last-week happy path: plan a few meals "last week" (temporarily allow past assign or seed rows in Supabase), tap Copy on the current week → meals land shifted +7, grocery list gains their ingredients.
3. Skip-filled: pre-plan one current-week day, copy → that day untouched, toast says "kept the day(s) you'd planned."
4. Mid-week: run on a week where Mon–Wed are past → those skip silently, no error banner.
5. Empty source: fresh week pair → "Last week was empty." toast, nothing written.
6. Contribution symmetry: remove a copied meal → its grocery contributions unwind exactly like a hand-assigned one.
7. Empty-week screen shows the third link; footer link hidden when every remaining day is planned or past.

## Next up

- David answers the 4 open decisions in `FEATURE_PER_PERSON_MEALS.md`.
- Archive/upload build 111 after verification (home iMac has the ASC key).
- Still parked: pantry-scan suggestions, community recipes, Engineer Mode (behind App Store blockers), join-by-code second-Apple-ID test, old Supabase project pause/delete.
