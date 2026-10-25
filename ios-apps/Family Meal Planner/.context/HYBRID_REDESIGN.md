# Hybrid redesign — 2026-10-25

Branch: `codex/fluffylist-hybrid-redesign`, based on main `21d1afe`. Approved reference: the user's four-screen Hybrid Recipe App UI Mockup. Build 126; build 125 was rejected by App Store Connect because that number was already used. No public App Store submission or main-branch merge.

## Implemented

- Warm adaptive surfaces, serif headings, rounded controls and title-case tab labels; browse hero/category/recent shelves and focused recipe search.
- Meal-category, time and favorite filters. Time filters exclude recipes with unknown total time.
- Recipe/Ingredients/Notes/Photos tabs, serving scaling, existing meal planning and separate grocery-only preview. Grocery preview explicitly uses the saved recipe quantities; it does not claim the on-screen serving adjustment is applied. It uses the existing manual merge path, preserving meal contributions.
- Original cookbook sources stay separate and uncropped, with a zoomable viewer. No fabricated photography, recipe descriptions, cooking dates or ratings.
- Private family-photo history with upload dates, captions, cover selection, reversible archive/restore and separate legacy saved photo. Cover validation is enforced in PostgreSQL; a cover must be reset before archiving it.
- Seasonal accents and pale tints: automatic Gregorian-calendar seasons, pinned palette, northern/southern hemisphere choice. Error/success colors stay stable. Refreshes on foreground and significant date changes.
- Weekly planner adopts the shared visual language while preserving existing service, calendar, copy-week, per-person and grocery behavior.

## Database deployment

Migration 020 was applied to FluffyList V2 (`papuusfhtojthtnbsdvs`) in a transaction on 2026-10-25. Read-only prerequisite checks confirmed the membership helper, recipe keys and the absence of the new table/bucket. Existing storage policies were limited to `recipe-images`. Post-deployment verification returned `family-recipe-photos`, public=false, photo_rls_enabled=true. No existing household, recipe, source-photo, meal-plan or grocery rows were rewritten.

The new policies were first tested in a disposable, network-isolated Supabase PostgreSQL 17 container. Tests cover two-household isolation, anonymous denial, private bucket, cover ownership, caption editing, archive/restore, immutable metadata and preventing removal of attached image objects. Clean application and reapplication passed. Storage SQL uses a minimal fixture: these tests do not exercise the Storage HTTP service or signed-URL image delivery.

## Validation

295 tests passed on each of iPhone 17 and iPad Pro 11-inch M5 (iOS 26.5), zero failures/skips. Final source run: `/private/tmp/fluffylist-125-final.xcresult`. Only the build number changed from 125 to 126 afterward. Hosted renderings cover five screens in light, dark and accessibility3 text; screenshots use synthetic text-only recipes, no actual household or fabricated food photos. All four seasonal accent palettes pass 4.5:1 text contrast on background/card surfaces in both appearances. Signed archive and App Store Connect upload succeeded for build 126 at 07:07 Eastern on October 25. Apple reported that the package is processing; processing completion and tester availability are unconfirmed.

## Remaining acceptance checks

Real-device VoiceOver, rotation/Split View, camera/photo-picker behavior with a real library, live two-account photo/signed-URL/cover synchronization, and scanning against the live proxy have not been exercised in this session. Existing scanning/auth/sync services are unchanged. The original local Secrets.xcconfig is consumed by Xcode for the signed archive; credential contents were not exposed. Do not describe simulator success as physical-device acceptance or an upload as Apple processing/tester availability.

The user authorized necessary Supabase changes and a TestFlight upload after checks, with no Claude-review prerequisite. A public App Store release remains unauthorized.
