# Round A — FluffyList Product & Data Assessment (Claude)
Author: Claude (Opus 4.7) | Date: 2026-05-28 | Mode: assessment, no changes

## The core finding: this is an ABANDONED app, not a bad one
Live DB shows last recipe added 2026-04-20, latest meal plan dated 2026-04-23 — ~5 weeks idle. The family stopped using FluffyList in late April, right around the auth/migration troubles that ended in the 2026-05-27 lockout. 0 of 40 grocery items are checked. Conclusion: the product's main problem is LOST TRUST from unreliability, not missing features. The highest-value work is reliability + polish that makes the family choose it again, not new capabilities.

## What the app is FOR (the bar to clear)
A shared family meal planner: plan meals on a calendar, keep recipes, auto-build a grocery list from the plan, shop from it together (David + Shannon + others). "Good" = Shannon opens it on Sunday, plans the week in 5 min, the grocery list is correct, and shopping from it on her phone just works. Today it doesn't clear that bar reliably.

## Data-layer observations (from live Supabase)
- Healthy real data: 15 recipes / 161 ingredients (~11 per recipe) — genuine use, not test junk.
- 0/40 grocery items checked — either shop-from-list flow is unused or broken. WORTH INVESTIGATING.
- Two user identities for David (dalbert71@me.com + david@highball71.com "David's iPad") both in the household — works, but "David's iPad" showing as a member name is sloppy UX.
- Schema is solid: RLS on, cascades correct, now has the one-household-per-owner guard. Backend is in better shape than the app's reputation suggests.

## Known product/UX rough edges (to verify with Codex's code view)
1. Reliability/trust — the #1 issue. Auth must never dump a returning user to onboarding again (fixed today, needs build+verify).
2. Grocery check state unused — is the shop-from-list experience actually working and pleasant on a phone in a store?
3. Member display names — "David's iPad" as a person is wrong; should be a person, not a device.
4. MealPlan vs PlannedMeal — two overlapping systems (per R000 map). Users may hit inconsistent behavior. Pick one.
5. The app has design investment (Heirloom palette, editorial type) but unknown if it's applied consistently across all screens.

## What I CANNOT assess (Codex's half)
- Code health, dead code (the IntervalTimer ghost, _disabled, _backup), test coverage (likely near zero).
- Whether the design system is applied uniformly or just in a few views.
- Build health, warnings, the MealPlan/PlannedMeal duplication at the code level.

## My proposed priority order (for David to set)
1. Verify today's auth fix actually builds and works (trust foundation).
2. Build a minimal test + headless-build harness — the prerequisite for any autonomous improvement (no grading = no autonomy).
3. Investigate the grocery shop-from-list flow (0 checked items is a red flag).
4. Resolve MealPlan vs PlannedMeal — one system.
5. Polish pass: member names, design-system consistency.

## Strategic note on autonomy goal
We cannot reach unattended "agents improve the app" until the app can grade itself. Items 1-2 above ARE the path to autonomy; features come after the app can measure its own health. Recommend building the harness BEFORE chasing features.
