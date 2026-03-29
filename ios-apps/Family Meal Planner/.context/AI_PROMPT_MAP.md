# AI_PROMPT_MAP.md — FluffyList

Use this file when asking Claude, ChatGPT, or Gemini for help. It defines key terms so agents don't waste time asking for definitions.

---

## Architecture & Frameworks
- **SwiftUI** — Apple's declarative UI framework (not UIKit)
- **Core Data** — Apple's local persistence framework (upgraded from SwiftData)
- **CloudKit** — Apple's cloud sync service (free tier, tied to iCloud)
- **TestFlight** — Apple's beta testing platform; builds are numbered (currently Build 92)

## CloudKit-Specific Terms
- **CKShare** — The sharing record CloudKit creates; contains metadata like `CFBundleVersion`
- **CKContainer** — The CloudKit database instance for the app
- **CKRecord** — Individual data item in CloudKit
- **applicationVersion / CFBundleVersion** — App build number; CloudKit stores this in share metadata; mismatch = "needs newer version" error
- **Share link** — URL or QR code Shannon taps to accept sharing; triggers CloudKit share UI

## Project-Specific Setup
- **Proxy Server:** https://fluffylist-proxy.onrender.com (Node/Express, Render free tier)
- **TestFlight Tester:** Shannon (wife); primary blocker is CloudKit share acceptance

## Features
- **Photo Scan:** Claude Vision API → extracts ingredients from photo → adds to meal plan
- **Ingredient Search:** Multi-item lookups
- **URL Import:** Add recipes from web URLs
- **Grocery List:** Persistent list pulled from all meal plans
- **Per-Person Ratings:** Rate meals on 1-5 scale
- **Weekly Planning:** Plan meals for the week
- **Multi-page scanning:** Photo scan can process multiple pages

## Known Issues
- **"0 pages scanned" bug:** Intermittent, appears in photo scan flow; mostly fixed but not 100%
- **CloudKit share metadata:** Recipient sees "needs newer version" if metadata version doesn't match
- **Data wipe on reinstall:** Not yet diagnosed
- **Photo scan cold-start delay:** ~50s from Render free tier sleep

## Repos & Links
- **Main app:** `github.com/Highball71/personal-projects` (ios-apps/Family Meal Planner/)
- **Proxy code:** `github.com/Highball71/fluffylist-proxy`
- **Live proxy:** https://fluffylist-proxy.onrender.com

## When Asking Agents for Help

### Good prompt:
"I'm on FluffyList (iOS, SwiftUI + Core Data + CloudKit). Shannon's CloudKit share link returns 'needs newer version'—see AI_PROMPT_MAP.md for context. The share was created on Build 92, and her app is also Build 92. What's the likely cause and fix?"

### Bad prompt:
"The share isn't working. How do I fix it?"
