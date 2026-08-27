# ACTIVE_TASK.md — FluffyList

**Session Focus:** Per-person meals Phase 1 — decisions stamped, migration 013 + model decode written and build-verified. Migration NOT yet applied (Supabase auth is for the wrong account on this machine).

---

## Completed This Session (August 27, 2026 — chat session, off-Mac)

0. **Verified repo state before acting** (probe, not prose): press-overhaul was already merged and build 110 already on TestFlight — the session brief's "item 1" was stale. HANDOFF corrected; next build is **111**.
1. **Copy last week** — commit on top of `main` (`9fd8e64`):
   - `MealPlanService`: `copyPreviousWeek(weekStart:recipeService:groceryService:)` + `fetchWeekRows` helper + `CopyWeekResult` tally. Reads both weeks fresh from DB; collapses legacy multi-row slots (first row, view convention); copies via `addMealWithGroceries` only onto confirmed-empty slots, so its clear-first step is a no-op and contributions carry over.
   - **Rules (David, 2026-08-27): skip filled days (keep existing); skip past days silently** (pre-filtered so the write path's past-date guard never raises).
   - View: "Copy last week" `FluffyTextLink` in the week footer (shown only when an open, non-past day exists) and in the empty-week link stack. Assigning overlay text parameterized ("Copying last week..."). Press-voice toasts ("Copied three dinners from last week." / "…kept the days you'd planned." / "Last week was empty.").
2. **Per-person meals design** → `FEATURE_PER_PERSON_MEALS.md`. Nullable `member_id` on meal_plans (NULL = household), composite-FK tenant safety + member-delete trigger, no RLS policy changes, per-member `dietary_preferences` keeping the onboarding promise, Press UI (chip row, kicker day rows), 3-phase rollout, 4 open decisions awaiting David.

## Completed This Session (August 27, 2026 — on-Mac, per-person meals Phase 1)

1. **Decisions stamped** into `FEATURE_PER_PERSON_MEALS.md` (all four, decided 2026-08-27): Option 1 nullable `user_id`; member meals contribute groceries identically; one meal per day per person (household slot + each member's slot are separate, no multi-meal-per-person); keyword-only dietary matching for v1.
2. **`supabase/migrations/013_member_meals.sql`** written exactly per the doc's migration section: nullable `user_id`, `dietary_preferences text[]`, unique index `(id, household_id)`, `meal_plans.member_id`, composite FK with **ON DELETE NO ACTION** (NOT SET NULL — it would null `household_id` too), `before delete` trigger on `household_members` nulling `member_id`. Re-runnable (IF NOT EXISTS / OR REPLACE / conditional constraint), like 004/006.
3. **Model changes, shipped dark:** `MealPlanRow.memberID: UUID?` via tolerant `try?` decode; `MealPlanInsert.memberID: UUID? = nil` (omitted from JSON when nil). No callers changed; no UI reads it.
4. **Verified:** sim build PASS + full test suite PASS (125/125). App behavior unchanged — nothing writes or reads `member_id` yet.
5. **⚠️ BLOCKED — migration not applied.** The Supabase MCP and CLI on this machine authenticate to a different account (only project visible: "Placatto"); `papuusfhtojthtnbsdvs` returns permission denied. Nothing was run against any database. **David: re-auth the Supabase connector (claude.ai connector settings or `/mcp` in an interactive session) or `supabase login` with the FluffyList account, then apply 013 and spot-check** (columns exist; cross-household `member_id` insert rejected by the FK; deleting a member nulls its meals via the trigger). The app is safe against the un-migrated DB in the meantime.
6. Local note: `Secrets.xcconfig` created from the template with the **placeholder** key so builds compile on this machine (gitignored).

## Verification checklist (on a Mac, before archiving 111)

1. `git am` the session patch from the `personal-projects` root (or pull if already pushed), build for device.
2. Copy-last-week happy path: plan a few meals "last week" (temporarily allow past assign or seed rows in Supabase), tap Copy on the current week → meals land shifted +7, grocery list gains their ingredients.
3. Skip-filled: pre-plan one current-week day, copy → that day untouched, toast says "kept the day(s) you'd planned."
4. Mid-week: run on a week where Mon–Wed are past → those skip silently, no error banner.
5. Empty source: fresh week pair → "Last week was empty." toast, nothing written.
6. Contribution symmetry: remove a copied meal → its grocery contributions unwind exactly like a hand-assigned one.
7. Empty-week screen shows the third link; footer link hidden when every remaining day is planned or past.

## Next up

- **Apply migration 013 to `papuusfhtojthtnbsdvs`** once Supabase auth is fixed (see BLOCKED item above), then run its spot-checks.
- Per-person meals Phase 2 (People screen, profile members, per-member dietary storage, AppStorage migration) when David says go.
- Archive/upload build 111 after copy-last-week verification (home iMac has the ASC key).
- Still parked: pantry-scan suggestions, community recipes, Engineer Mode (behind App Store blockers), join-by-code second-Apple-ID test, old Supabase project pause/delete.
