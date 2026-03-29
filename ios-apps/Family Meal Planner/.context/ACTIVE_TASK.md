# ACTIVE_TASK.md — FluffyList

**Current Objective:** Fix CloudKit share acceptance error so Shannon can open the app.

## The Problem
Shannon receives share link, taps it, gets error: **"Couldn't Open 'Family Meal Planner' — Need a newer version"**
- She has the latest TestFlight build (Build 92)
- Root cause: `CFBundleVersion` metadata embedded in `CKShare` at creation time
- When SwiftData's `NSPersistentCloudKitContainer` creates the share, it stores the app's build number
- CloudKit rejects shares if recipient's build is lower than metadata

## Immediate Next Step
**Delete and recreate the share on iPhone:**
1. Open Family Meal Planner on iPhone
2. Navigate to Settings → Sharing
3. Delete Shannon's existing share link
4. Create new share link (this will embed current Build 92 metadata)
5. Send new link to Shannon
6. Have her tap it and accept

**Expected outcome:** New share has correct metadata; Shannon can open app.

## If Manual Deletion Doesn't Work
1. Increment `CFBundleVersion` in Xcode to 93
2. Archive and push to TestFlight
3. Shannon updates to Build 93
4. Recreate share on your iPhone
5. Shannon accepts new share with fresh metadata

## Pre-App Store Checklist (After Share Fix)
- [ ] Flip `aps-environment` to production in entitlements
- [ ] Confirm photo scan "0 pages scanned" bug doesn't regress
- [ ] Build iPad-native layout
- [ ] Confirm spending limits
- [ ] Final TestFlight round before submitting to App Store

## Blocked By
- CloudKit share metadata issue (in progress)

## Not Blocked
- Photo scan bug (intermittent, not blocking release)
- URL import feature (working)
- Grocery list persistence (fixed)
