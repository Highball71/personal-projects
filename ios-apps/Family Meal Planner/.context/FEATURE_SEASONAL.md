# FEATURE — Seasonal Suggestions (design only, not yet built)

Drafted 2026-08-30 (chat session) from David's idea, inspired by Noma's
season-driven menus and the Japanese 24-sekki cooking calendar.
Status: **PARKED — do not start before Per-Person Meals Phases 2–3 ship.**
Four design decisions below are SETTLED (2026-08-30, David deferred to
Claude's judgment). Build session should not reopen them.

---

## Goal

Surface recipes whose ingredients are in season *right now, where this
household lives*. Discovery, not enforcement: the picker nudges toward
seasonal food; it never hides anything.

## Why it fits this app

Both inputs already exist: recipes carry ingredient lists (the grocery
contributions), and the AI proxy (PROXY_KEY) is wired for suggestion work.
No new schema is required for v1.

## The one hard problem: seasonality is regional

Tomatoes peak in August in Slippery Rock and in February in Florida. The
feature needs a coarse household location. One setting is enough:
**region = one of ~8 US regions** (see Decisions). Hemisphere-flip for
non-US users is a later concern.

## Data source (v1 decision recommended)

**Bundled JSON calendar** — 12 monthly periods × ~8 US regions × produce
names. Curated once, ships in the app bundle. Deterministic, offline, no
schema, easy to correct. Upgrade path: let the AI proxy generate + cache a
calendar for regions the bundle doesn't cover.

Rejected for v1: live web/produce APIs (network dependency, cost, flaky
coverage) and per-recipe manual season tagging (nobody will do it).

## Matching

Same approach already approved for dietary preferences in
FEATURE_PER_PERSON_MEALS: **keyword-only**. For each recipe, count
ingredient names that match the current period's produce list for the
household's region. Score = hit count, peak produce weighted above
merely-available produce. Zero hits = not seasonal, still shown, just not
promoted.

## v1 surface (small on purpose)

- "In season now" section at the top of the Choose a Recipe sheet, sorted
  by score, capped (5–8 items).
- Small leaf badge on qualifying recipe rows elsewhere.
- Region picker in Settings (one row). Unset region = feature dormant, no
  nagging.

Not in v1: seasonal recipe *generation*, per-period themed menus, notes on
what's "coming into season next," anything touching meal_plans.

## Pairing that makes it pay off

Households with a thin recipe library get nothing from matching alone. The
natural companion is the existing AI recipe-suggestion path: pass the
current period's produce list into that prompt so "suggest something" leans
seasonal even when the library is empty. Track as v1.5.

## Risk / cost estimate

Phase-2-sized, not Phase-3-sized: one Settings row, one bundled JSON, one
scoring function, one new section in an existing sheet. No RLS, no
migration, no meal_plans semantics. Main cost is curating the calendar
honestly — sloppy produce lists make the feature look wrong fast.

## Decisions (settled 2026-08-30)

1. **Region = ~8 hand-drawn US regions** (Northeast, Mid-Atlantic, Southeast,
   Midwest, Plains, Southwest, Pacific NW, California) — not USDA zones
   (they measure winter cold, not harvest timing, and users don't know
   theirs) and not 50 states (uncuratable). One Settings row.
2. **Twelve monthly periods**, not 24 sekki — finer than curated produce
   data can honestly support. Labels may borrow sekki-style poetry
   ("late August") without the calendar system.
3. **Two tiers: peak vs. available.** One flag per produce entry. "In
   season now" ranks peak hits above available hits.
4. **AI seasonal-suggestion pairing is v1.5.** Ship matching first; decide
   after seeing real library sizes.

## Competitive note (2026-08-30 search)

Mainstream planners (Mealime, Plan to Eat, AnyList, eMeals) don't do
seasonality; their differentiators are pantry-awareness and grocery lists.
Honeydew Recipe Manager does (zip/geo → state produce list, half-month
intervals, home-screen "in season"). Seasonal Food Guide exists as a
standalone reference app. So: a differentiator, not a moat. FluffyList's
edge is seasonality inside a *family* planner where it meets per-person
meals and the shared grocery list — no one has that combination.

## App icon + rollout (decided 2026-08-30)

- **New icon direction chosen: the half fig** (cut cross-section, ink on
  paper, Press woodcut style). Beat an heirloom tomato and an inverted fig
  in a side-by-side at 60px. Sketch SVGs live in the chat session outputs;
  needs one polishing pass (seed pattern, stem) before a 1024 PNG goes
  into the asset catalog.
- **HOLD the icon change.** Do not ship it in build 111 or any interim
  build. It launches together with per-person meals + seasonal
  suggestions as one coordinated rollout, announced by email (or similar)
  to the household/testers.
