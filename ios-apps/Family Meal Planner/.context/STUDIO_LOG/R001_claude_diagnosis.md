# R001 — Duplicate Household Bug: Claude's Independent Diagnosis
Author: Claude (Opus 4.7) | Date: 2026-05-28 | Mode: diagnosis only, no fix yet

## What I know that Codex can't see (live database reality, from Supabase MCP session 2026-05-27)
- Project papuusfhtojthtnbsdvs (FluffyList V2) is the live one. Old project dbunenacikpeeplnltrz is now PAUSED.
- Live row counts: 3 auth users, 4 households, 4 household_members, 15 recipes, 10 meal_plans, 40 grocery_items.
- ALL FOUR households are named "The Alberts" and ALL are owned by the same user_id (32858ad2-ca2d-43eb-9de8-9809262d3c01), created April 9-10. This is the duplicate bug, captured in the data.
- The migrations ARE applied to the live DB (the constraints Codex found in SQL files match what I queried live). So Codex's line-52 uncertainty is resolved: yes, applied.
- Yesterday a phantom-user JWT bug also occurred (Apple sub collision created a session for a user_id absent from the DB), but a fresh sign-in cleared it. Likely separate from the duplicate-household bug, but may share a root cause in the sign-in/onboarding gate.

## My diagnosis of the duplicate-household bug
Root cause is a missing idempotency guard at the onboarding gate, NOT a database problem.

Sequence:
1. App launches, user signs in (or session restores).
2. AppRootView checks SupabaseManager.currentHouseholdID. On a cold launch this is nil because membership hasn't loaded yet - it's an async fetch.
3. The gate treats nil as "no household exists" and routes to HouseholdOnboardingView.
4. User (reasonably) taps Create. createHousehold inserts a brand-new household + member row with NO check for an existing membership.
5. Repeat across sessions/devices -> 4 identical households.

The DB even permits it: household_members has UNIQUE (household_id, user_id), but that does NOT stop one user OWNING many DIFFERENT households. Each duplicate is a distinct household_id, so the unique constraint never trips.

## The two-part nature of the fix (proposing, not implementing)
1. CLIENT (the real fix): before routing to onboarding, AppRootView must AWAIT a definitive membership load. Distinguish three states: (a) loading/unknown, (b) confirmed-no-household, (c) has-household. Only state (b) shows onboarding. Right now (a) and (b) are conflated as nil.
2. SERVER (defense in depth): consider a partial unique index enforcing "one owned household per user" IF the product rule is one household per owner. BUT - need to confirm that rule with David. A user might legitimately belong to multiple households later. Owning multiple is the question. Likely answer: a user should own AT MOST one, but can JOIN others.

## Cleanup needed regardless of fix
The 3 surplus "The Alberts" households must be merged/deleted, with child rows reassigned to the surviving household. Must pick the household that owns the 15 recipes / 40 grocery items as the survivor. Query which household_id holds the real data before deleting anything.

## Confidence
High (85%) on the client-side root cause. Medium on the server-side rule pending David's product decision. Cleanup is mandatory and must precede or accompany the fix.

## Open question for the postmaster (David)
Product rule: should a single user be allowed to OWN more than one household? My assumption is no (own one, join many). Confirm and the server-side guard becomes clear.
