# Family Meal Planner (FluffyList) — STATUS.md
**Last updated: 2026-03-28 (Phase 1 audit)**

---

## Current State

| Field | Value |
|-------|-------|
| Status | Active — pre-App Store |
| TestFlight | Build 92 (as of March 2026) |
| Repo | `github.com/Highball71/personal-projects` |
| Local path | `~/Documents/personal-projects/ios-apps/Family Meal Planner/` |
| Proxy | `https://fluffylist-proxy.onrender.com` (Render free tier, Node/Express) |

---

## Recent Git Log (last 10 commits to this path)

| Hash | Message |
|------|---------|
| f148739 | Fix CloudKit sharing: async share API, stale FetchRequest guard, zone cleanup |
| 1d3f38f | Core Data + CloudKit migration, fix 22 warnings, add sync-ready sharing gate |
| 9cf75d7 | Store shared model enums as raw strings for CloudKit sharing |
| 580f2c0 | before enum CloudKit fix |
| c514745 | Fix CloudKit sharing - hard reset and schema fixes |
| d327135 | Differentiated scan error messages, increased timeout to 120s |
| f49298f | Switch to proxy server, remove user API key requirement, fix photo scan bug |
| e629055 | Fix 0 pages scanned bug — use onChange instead of onDismiss |
| d966b4b | Standardize naming — FluffyList in comments, logs, and runtime strings |
| 14eef6f | Standardize logging — replace print() with os.Logger, gate verbose content |

---

## Working Features

- Family meal planning (recipes, ratings)
- CloudKit sync (schema deployed to production)
- Multi-page photo scanning via Anthropic proxy (up to 5 pages)
- Per-person recipe ratings
- Grocery list with checked-state persistence
- Proxy-based API key auth (user-facing key removed; `X-Proxy-Key` header)
- CloudKit household sharing (share sheet functional; Shannon share pending acceptance)

---

## Known Issues / Blockers

| Issue | State |
|-------|-------|
| Shannon CloudKit share acceptance | Pending (link sent March 16) |
| Data wipe on reinstall | Reported, not yet diagnosed |
| "0 pages scanned" bug | Fixed via onChange approach; still intermittent |
| Photo scan cold-start delay (~50s) | Render free tier behavior — known, acceptable |

---

## Pre-App Store Checklist

- [ ] Move `PROXY_KEY` out of hardcode in `AnthropicClient.swift` into gitignored config
- [ ] Flip `aps-environment` to production
- [ ] Confirm photo scan fix holds in TestFlight
- [ ] Build iPad-native layout (currently scaled phone UI)
- [ ] Confirm spending limit is sufficient for App Store launch volume

---

## Next Feature

- Ingredient-based recipe finder (find recipes based on what's on hand)
- Dietary features (relevant: niece nutritionist visit, possible diabetes diagnosis)

---

## Git Status (as of audit)

Working tree: clean — no uncommitted changes.
