# R003 — Auth / Onboarding Hull Check: Remediation (Swift side)

**Author:** Claude (Builder/Architecture)
**Date:** 2026-05-28
**Phase:** Hull Check (§5) → remediation
**Scope:** Returning-user auth / onboarding trust path (Supabase). Swift only — DB/RLS owned by the other Claude and was fixed separately.

## Context
A prior hull check (recon) on the returning-user auth path found 7 holes. The DB
side (RLS lockdown + new `join_household_by_code` RPC) was implemented and went
live separately. This entry covers the Swift-side fixes, worked in priority order.

## Changes

### 1. CRITICAL — Join flow now uses the RPC (was a client-side SELECT)
`HouseholdService.joinHousehold` no longer SELECTs `households` by `join_code`
(now blocked by RLS). It calls `supabase.rpc("join_household_by_code", params:
["p_code": code])`, which returns the household uuid or raises `invalid_join_code`.
Flow: resolve code → self-insert into `household_members` (still allowed by RLS)
→ read the household back as a member → `setCurrentHousehold`.
- `invalid_join_code` → friendly "No household found with that code."
- Unique-violation (already a member) → treated as success via `loadExistingHousehold`,
  so a returning member re-entering a code lands in their household instead of erroring.
- Create flow untouched (owner can still SELECT their own row).

### 2. CRITICAL — Config errors are recoverable, not a launch crash
`SupabaseManager.init` previously `fatalError`'d on missing/empty/invalid
`SUPABASE_URL` / `SUPABASE_ANON_KEY` — and since the singleton is built at App
init, that was a crash-on-launch loop. Now it sets a published `configError` and
constructs a placeholder client so init completes. `AppRootView` gates on
`configError` first and renders `ConfigErrorView` (states exactly which key to fix
in `Secrets.xcconfig`). The placeholder client is never exercised because routing
stops at the error screen.

### 3. HIGH — checkSession distinguishes transient vs invalid session
`AuthService.checkSession` no longer treats every thrown error as "signed out."
New `isTransientError` classifies `URLError`/`NSURLErrorDomain` connectivity
failures as transient. On transient failure the user is kept out of the sign-in
wall and shown a retry (`.restoreFailed`); only a genuinely missing/invalid
session routes to `SignInView` (`.signedOut`). This fixes the offline-blip →
inescapable sign-in wall path.

### 4. HIGH — Added a `.restoring` auth state; routing gates on it
New `AuthService.SessionState { restoring, signedIn, signedOut, restoreFailed }`,
default `.restoring`. `AppRootView` now routes through `sessionGate` on this state,
mirroring the existing membership `.loading` pattern. Returning, already-signed-in
users see a brief "Restoring your session…" view instead of a SignInView flash on
every cold launch.

### 5. MEDIUM — Membership lookup timeout
The `household_members` lookup in `loadHouseholdMembership` is wrapped in a 12s
`withTimeout` helper. A hang now transitions membership to `.failed` (which already
has a Retry button) instead of spinning on "Loading your household…" forever.

### 6. MEDIUM — Foreground session re-check
`AppRootView` observes `scenePhase`; on return to `.active` (past onboarding,
configured) it calls `AuthService.revalidateOnForeground`. That silently confirms
the session — if the token died while backgrounded it routes to sign-in; transient
failures leave the user in place. No `.restoring` flash on foreground.

### 7. LOW — Cleanup
- Removed the `Task.sleep(500ms)` "debug delay" from create + join.
- Removed dead `SupabaseManager.refreshSession()` (never called).
- Removed the raw `SUPABASE_URL` console print and the other init diagnostics.
- Gave the new status views (and the existing membership-loading view) full-frame
  `Color.fluffyBackground` so they don't read as a broken half-screen.

## Files touched
- `FluffyListBeta/Services/HouseholdService.swift` — join via RPC, drop sleeps.
- `FluffyListBeta/Services/SupabaseManager.swift` — recoverable config, drop dead code/prints.
- `FluffyListBeta/Services/AuthService.swift` — SessionState, transient classification,
  foreground revalidation, membership timeout, `withTimeout`/`TimeoutError` helper.
- `FluffyListBeta/Views/AppRootView.swift` — sessionGate routing, scenePhase observer,
  ConfigErrorView / AuthRestoringView / SessionRestoreRetryView.

## Verification
- `bash scripts/build.sh` → **BUILD SUCCEEDED** (iOS simulator, compile-only).
- Not yet exercised on-device against the live Supabase project (no end-to-end run
  of sign-in / join / offline / foreground-expiry in this session).

## Follow-ups / not done
- Verify RPC scalar decodes to `UUID` against the live function (built assuming a
  bare `uuid` scalar return; if it returns a wrapped row, switch to decode-as-row).
- Duplicate-household write-race (double-tap Create) remains: the DB has no
  `owner_id` unique constraint, so the client `isUniqueViolation`/`one_owned_household_per_user`
  branch is still dead. Out of scope here (DB-owned) — flagged for the DB Claude.
- The over-broad `"Anyone can read household by join code" using(true)` policy was
  the reason for this RPC change; assume the DB Claude has since tightened it.
