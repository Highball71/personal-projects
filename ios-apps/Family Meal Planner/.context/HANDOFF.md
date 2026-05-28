# HANDOFF.md — FluffyList

**Read this first.** Concise current state. Detailed trail lives in `.context/STUDIO_LOG/`.

Last updated: 2026-05-28 (end of day)

---

## Where things stand

FluffyList's **returning-user auth / onboarding trust path** was hull-checked and hardened today, across both the database and the Swift app, and **verified live on a physical device with a real account and real data.** This was the first full run of the multi-AI loop (Claude = database/architecture via Supabase MCP, Claude Code = Swift, Codex = local executor, David = director).

### Shipped today

**Database (Supabase ref `papuusfhtojthtnbsdvs`), applied + committed:**
- Removed wide-open `households` RLS policies; scoped to owner-writes / owner-or-member reads.
- Added `join_household_by_code()` SECURITY DEFINER RPC so joining no longer requires exposing every household's join code.
- Added missing policies: `household_members` leave/edit, `recipes` UPDATE, `recipe_ratings` read + author-update.
- Fixed the **cascade-delete bug**: deleting a recipe now clears it from the calendar (`meal_plans.recipe_id` → ON DELETE SET NULL) instead of throwing an FK error. Household deletion now cascades meal plans + groceries consistently.
- Pinned `is_household_member` search_path. Security advisor clean (remaining notices are by-design SECURITY DEFINER + a moot password-protection flag — app uses Sign in with Apple).
- Captured in migrations **011** and **012** (the latter documents a unique index that existed live but was never in a migration — see "Drift lesson" below).

**Swift (commit `338bcf3`):** all 7 hull-check findings fixed — join flow switched to the RPC, launch no longer crashes on missing config (recoverable `ConfigErrorView`), offline session blip no longer dumps users to a sign-in wall (`.restoreFailed` + retry), no more SignInView flash (`.restoring` state), membership-lookup timeout, foreground re-validation, debug cleanup. Live Supabase keys wired into the gitignored `Secrets.xcconfig`. Build green; STUDIO_LOG = R003.

### Verified live (real device, real account, live backend)
Sign in with Apple → session restore → household membership read → real recipe/meal-plan data all load correctly through the rewritten RLS. The `sb_publishable_` anon key is accepted on live requests (no apikey 401). The trust path is confirmed working.

---

## Not done yet (next session)
1. **Ship a fresh build (103).** TestFlight Build 102 still has the OLD client-side join flow, which the RLS lockdown now blocks. Anyone joining on 102 will fail until a build with `338bcf3` ships. Not urgent (pre-launch, empty DB) but it's the gate before real users.
2. **Second-account join test** through the new `join_household_by_code` RPC (needs a 2nd Apple ID — couldn't test with one account).
3. **Cascade-delete runtime check:** delete a recipe that's assigned to a calendar day, confirm the slot clears gracefully.
4. **Offline-retry view** (`.restoreFailed`) — needs an induced network failure to see.
5. **Fix stale note:** Claude Code's R003 log still calls the `one_owned_household_per_user` catch branch "dead code." It is NOT — the unique index exists live (now in migration 012). Correct that line when next editing.

---

## Drift lesson (worth remembering)
Today's two-angle hull check exposed that the **live database had drifted from the migration files** in three places (a wide-open policy, a join-code policy, a unique index) — all added via the dashboard, none captured in code. Neither the code-reading AI nor the DB-reading AI caught it alone; together they did. Migrations 011/012 reconciled it. Keep schema changes in migrations, not the dashboard.

---

## Project facts
- Supabase: `papuusfhtojthtnbsdvs` (active). Old `dbunenacikpeeplnltrz` should be paused/deleted.
- Repo: FluffyList at `personal-projects/ios-apps/Family Meal Planner/`; git index is in the **parent** `personal-projects` repo (Codex flagged this — stage paths accordingly).
- Bundle `com.highball71.fluffylist.beta`, team `A5DP57PZ7N`, device "Dad's iPhone" registered.
- `PROXY_KEY` is the one real secret — lives in gitignored `Secrets.xcconfig`, never commit it.
- Known housekeeping (not urgent): repo structure is tangled (Fast No Slow files mixed in); `ACTIVE_TASK.md` had drifted stale — keep `.context` current each session.
