# HANDOFF.md — FluffyList

## One-Paragraph Resume
FluffyList (Build 92) is on TestFlight and ready for final pre-App Store push. The critical blocker is CloudKit sharing: Shannon's share link returns "needs newer version" error because `CFBundleVersion` metadata in the `CKShare` doesn't match. Solution: delete and recreate the share on iPhone, which will embed fresh metadata. After that: flip `aps-environment` to production, verify photo scan bug is fixed, build iPad layout, then submit to App Store.

---

## Current Status
- **Build:** 92 (TestFlight, live)
- **Branch:** main
- **Device:** iPhone (for share recreation; iMac for code)
- **Last Activity:** Shannon received share link, got metadata error
- **Proxy:** https://fluffylist-proxy.onrender.com (Render free tier, Node/Express)

## What's Working
- Photo scan (Claude Vision API) — intermittent "0 pages scanned" bug, but not blocking
- Ingredient search
- URL import (working)
- Grocery list persistence (fixed)
- Proxy authentication
- CloudKit sync (production schema deployed)
- Multi-page photo scanning
- Per-person recipe ratings
- Weekly meal planning

## What's Broken
- **CloudKit share acceptance** — Shannon gets "needs newer version" error
  - Root cause: `CFBundleVersion` in `CKShare` metadata mismatch
  - Status: Ready for manual delete/recreate on iPhone
- **Data wipe on reinstall** — Not yet diagnosed
- **Photo scan cold-start delay** — ~50s from Render free tier

## Critical Files
- `AnthropicClient.swift` — Proxy integration
- `Entitlements.plist` — `aps-environment` currently set to development, needs flip to production
- `Info.plist` — `CFBundleVersion` = 92

## Repos
- **Main:** `github.com/Highball71/personal-projects` (contains ios-apps/Family Meal Planner/)
- **Proxy:** `github.com/Highball71/fluffylist-proxy`

## Next Steps (In Order)
1. Delete Shannon's share on iPhone, recreate it, have her accept
2. Verify share acceptance works
3. Flip `aps-environment` to production
4. Build iPad-native layout
5. Confirm spending limits
6. Final ingredient/photo scan test
7. Submit to App Store

## What to Check First When Resuming
- Has Shannon accepted the new share link yet?
- What was the last error message?
- Are you on home iMac or office iMac?
