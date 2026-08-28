# ACTIVE_TASK.md — FluffyList

**Session Focus:** (2026-08-27 evening — chat + device) Migration 013 applied to production; copy-last-week device-verified; pre-existing grocery-unwind bug found and diagnosed. Next session: fix the unwind, then archive 111.

## State after tonight

- **Migration 013 APPLIED** to `papuusfhtojthtnbsdvs` via dashboard SQL Editor (connector/CLI still auth'd to the wrong Supabase account — reconnect in claude.ai settings before expecting MCP DB access). Column-verified: `meal_plans.member_id` present; `household_members.user_id` nullable = YES; `dietary_preferences` present. FK/trigger spot-checks (cross-household insert rejected; member delete nulls meals) deferred — low risk, run before Phase 3.
- **Copy-last-week DEVICE-VERIFIED** on Dad's iPhone: link hidden when no open future day PASS; link appears after freeing a day PASS; partial copy (1 dinner into Friday, filled days kept, past days silently skipped) PASS; re-tap no duplicates PASS. Checklist items 6/7 as previously written were untestable — the Press week view has **no week navigation** (current week only); empty-source toast remains unverified on device, acceptable.
- **NEW BUG (pre-existing, ships in 110): removing a meal strands its grocery items.** Root cause: `clearDayWithGroceries` (the week view's only removal path) deletes `meal_plans` rows FIRST, then calls `removeContributions(forMealPlan:)` — but `grocery_contributions.meal_plan_id` is ON DELETE CASCADE (migration 005), so the contribution rows are already gone; the unwind finds zero and reports success. The delete-first ordering was a deliberate RLS-safety choice; the cascade silently defeats it. **Fix plan:** snapshot the contribution rows for the affected meal ids BEFORE the delete, verify the delete, then settle grocery quantities from the snapshot (keeps the RLS-safety intent). Add a regression test. Note `removeMeal(_:)` uses unwind-first ordering and works, but is not the path the view uses.
- **Dark mode fixed globally:** `UIUserInterfaceStyle = Light` in Info.plist (commit 20b4316). Press has no dark palette; recipe sheet was black-on-black on a Dark Mode phone. The lone per-view `.preferredColorScheme(.light)` in SupabaseAddRecipeView is now redundant.
- **Secrets template completed:** `Secrets.xcconfig.template` now includes `SUPABASE_URL` / `SUPABASE_ANON_KEY` placeholders (with the xcconfig `//`-comment escape). This machine (Mac-1929) has real Supabase values; **PROXY_KEY here is still the placeholder → archives must come from the home iMac.**
- **Two households exist in prod:** David's (13 recipes) and a second (~"Neuro and the Divergent...", 1 recipe, real meal on 2026-08-20) — likely the tester's own household. Chat-session test seeds there were removed same night. David's household carries seeded meals on 2026-08-20..22 (his own recipes; harmless history).
- **Old Supabase V1 project `dbunenacikpeeplnltrz` PAUSED** 2026-08-27 (slot freed, data recoverable).

## Next up

1. **Claude Code session: grocery-unwind fix** per the plan above + regression test. Then **archive/upload build 111 from the home iMac** (real PROXY_KEY + ASC key live there) — 111 ships copy-last-week + light-mode + the unwind fix together.
2. Per-person meals **Phase 2** (People screen, profile members, per-member dietary prefs, AppStorage migration) when David says go.
3. Parked: join-by-code second-Apple-ID test; Engineer Mode; pantry-scan suggestions; community recipes; toast icon string-match cosmetic.
