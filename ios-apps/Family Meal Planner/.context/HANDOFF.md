# HANDOFF.md — FluffyList

## One-Paragraph Resume
FluffyList Beta (Build 92) is on TestFlight. The app is a household meal planner with recipes, grocery lists, and CloudKit sharing. The main goal right now is **reliable household sharing** — Shannon (David's wife) needs to be able to accept a CloudKit share and use the app as a shared household member. The current blocker is an inconsistent share flow: the share link triggers a "needs newer version" error due to `CFBundleVersion` metadata embedded in the `CKShare` at creation time. The beta app has been given a distinct temporary icon (different from the original orange/spoon icon) so testers can immediately distinguish it from any production FluffyList install.

---

## Current Status
- **Build:** 92 (TestFlight, live)
- **Branch:** main
- **Bundle ID:** com.highball71.fluffylist.beta
- **Display Name:** FluffyList Beta
- **Device:** iPhone (for share recreation; iMac for code)
- **Proxy:** https://fluffylist-proxy.onrender.com (Render free tier, Node/Express)

## Main Goal
**Reliable household sharing via CloudKit.**

## What's Working
- Photo scan (Claude Vision API) — intermittent "0 pages scanned" bug, not blocking
- Ingredient search
- URL import
- Grocery list persistence (fixed)
- Proxy authentication
- CloudKit sync (production schema deployed)
- Multi-page photo scanning
- Per-person recipe ratings
- Weekly meal planning

## What's Broken / Blocking
- **CloudKit share acceptance** — Shannon gets "needs newer version" error
  - Root cause: `CFBundleVersion` in `CKShare` metadata mismatch between builds
  - Fix: Delete and recreate the share on iPhone (embeds fresh Build 92 metadata)
- **Inconsistent share flow** — the overall share-accept-collaborate cycle is unreliable
- **Data wipe on reinstall** — Not yet diagnosed

## Critical Files
- `AnthropicClient.swift` — Proxy integration
- `Entitlements.plist` — `aps-environment` currently set to development, needs flip to production
- `Info.plist` — `CFBundleVersion` = 92
- `Assets.xcassets/AppIcon.appiconset/` — Beta icon (temporary, distinct from production)

## Repos
- **Main:** `github.com/Highball71/personal-projects` (contains `ios-apps/Family Meal Planner/`)
- **Proxy:** `github.com/Highball71/fluffylist-proxy`

## Next Steps (In Order)
1. Delete Shannon's share on iPhone, recreate it, have her accept
2. Verify share acceptance works end-to-end
3. If still failing, increment build to 93 and push new TestFlight
4. Flip `aps-environment` to production
5. Build iPad-native layout
6. Final ingredient/photo scan test
7. Submit to App Store

## What to Check First When Resuming
- Has Shannon accepted the new share link yet?
- What was the last error message?
- Is the beta icon showing correctly on device?
