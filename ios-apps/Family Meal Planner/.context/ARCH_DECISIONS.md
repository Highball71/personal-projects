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

## Decision: CloudKit for Sync, Not Custom Backend (SUPERSEDED)
**Date:** Early 2025
**Status:** SUPERSEDED by Supabase (April 2025)
**Why it was chosen:**
- Free tier (tied to iCloud accounts)
- Apple-native, works offline

**Why it was replaced:** CloudKit sharing was unreliable — `CKShare` metadata version mismatches caused "needs newer version" errors with no practical automated fix. Household sharing is the app's core feature and CloudKit made it fragile.

---

## Decision: Supabase for Shared Data + Auth
**Date:** April 2025
**Status:** Active (scaffolding complete, integration testing pending)
**Why:**
- Explicit control over sharing via row-level security
- Join-code flow is simpler and more reliable than CKShare
- Sign in with Apple via Supabase Auth
- PostgreSQL gives us full SQL power for queries
- Free tier is generous for a household app

**Trade-offs:**
- No offline support initially (Supabase is always remote)
- Adds a third-party dependency (supabase-swift)
- Requires managing a Supabase project

**Implementation:**
- Feature flag `useSupabase` in `Family_Meal_PlannerApp.swift`
- Old CloudKit code preserved, not deleted
- SQL schema in `supabase/migrations/001_initial_schema.sql`
- Service layer in `Services/Supabase/`

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
- **SwiftUI must stay** (rewriting in UIKit would set back 2+ months)
- **Proxy must be kept** (API key can't live on device)
- **Old CloudKit code stays** until Supabase is fully validated

---

## Pending Decisions
- **App Store submission date:** TBD (after CloudKit share fix + pre-App Store checklist)
- **iPad layout:** Needed for App Store approval
- **Spending limits:** Need to confirm before launch
