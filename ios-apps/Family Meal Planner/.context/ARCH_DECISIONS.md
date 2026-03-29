# ARCH_DECISIONS.md — FluffyList

Record of architectural decisions and constraints that should not be re-litigated.

---

## Decision: SwiftUI + Core Data for Core App
**Date:** Early 2025
**Status:** Locked in
**Why:**
- SwiftUI is Apple's modern declarative UI framework
- Core Data is battle-tested for iOS persistence
- Both are standard for iOS apps in 2025
- Better performance and tooling than alternatives

---

## Decision: CloudKit for Sync, Not Custom Backend
**Date:** Early 2025
**Status:** Locked in, but complex
**Why:**
- Free tier (tied to iCloud accounts)
- Apple-native, works offline
- Family sharing use case fits CloudKit's design
- No cost for data transfer

**Constraint:** CloudKit sharing metadata includes `CFBundleVersion`. If recipient's build is lower, CloudKit rejects. Solution: delete and recreate share if metadata mismatch occurs.

---

## Decision: Proxy Server for Claude Vision API
**Date:** March 16, 2025
**Status:** Live (Render free tier)
**Why:**
- Claude Vision API requires server-side calls (can't call directly from iOS)
- Render free tier is free and quick to deploy
- Node/Express is fast to iterate on
- Proxy keeps API key off the client

**Constraint:** Render free tier sleeps after 15 min of inactivity. Keepalive ping added to prevent sleep.

---

## Decision: Photo Scan via Claude Vision
**Date:** Early 2025
**Status:** Locked in
**Why:**
- Claude Vision is more accurate for complex ingredient lists
- Photos uploaded to proxy, processed server-side, deleted after processing
- No data retention

**Known Issue:** Intermittent "0 pages scanned" bug. Root cause unclear; may be race condition or Vision API timeout.

---

## Decision: Grocery List as Derived State
**Date:** Early 2025
**Status:** Locked in
**Why:**
- Grocery list is computed from all meals' ingredients
- Storing it separately = sync burden
- Deriving it from meals = single source of truth

---

## Decision: Per-Person Ratings
**Date:** Early 2025
**Status:** Locked in
**Why:**
- Different people like different meals
- Rating is personal preference, not absolute

---

## Decision: App Store Launch Before Other Apps
**Date:** Early 2025
**Status:** Locked in
**Why:**
- FluffyList is furthest along; unblocking it clears mental load
- ClinicOS has hard April 18 demo deadline (separate project)

---

## What NOT to Change
- **CloudKit must stay** (alternative backends require major rework)
- **SwiftUI must stay** (rewriting in UIKit would set back 2+ months)
- **Proxy must be kept** (API key can't live on device)

---

## Pending Decisions
- **App Store submission date:** TBD (after CloudKit share fix + pre-App Store checklist)
- **iPad layout:** Needed for App Store approval
- **Spending limits:** Need to confirm before launch
