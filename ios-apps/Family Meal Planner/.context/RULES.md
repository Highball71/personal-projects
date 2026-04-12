# RULES.md — FluffyList

## Session Rules
- **Do NOT split repos** yet. Audit only.
- **Do NOT move, rename, or delete** any project files or folders.
- **No work on other projects** — FluffyList only.
- **Do NOT design a final brand icon.** The beta icon is temporary.
- **Do NOT delete old CloudKit code.** Isolate it behind the feature flag.

## Architecture Rules (Supabase Migration)
- Supabase is the source of truth for shared data.
- Feature flag `useSupabase` in `Family_Meal_PlannerApp.swift` controls which path runs.
- Old CloudKit path preserved under `useSupabase = false`.
- New Supabase services go in `Services/Supabase/`.
- New Supabase models go in `Models/Supabase/`.
- New auth/onboarding views go in `Views/Auth/`.

## Project Rules
- All UI is SwiftUI (never UIKit).
- Target iOS 17+.
- Use Swift async/await for concurrency.
- No third-party dependencies unless absolutely necessary (Supabase is the exception).
- Sensitive credentials go in `Secrets.xcconfig`, never in code or committed to git.
- Never read or commit `.env` files, API keys, or secrets.
- Files using `@Published` must `import Combine` (MemberImportVisibility enabled).

## Naming
- The app's display name on device is **FluffyList Beta**.
- The Xcode project is still called **Family Meal Planner** (historical name).
- The bundle ID is `com.highball71.fluffylist.beta`.
- In code comments and logs, use "FluffyList" (not "Family Meal Planner").

## Context System
- All session state lives in `.context/` directory.
- Update `HANDOFF.md` at end of each session.
- Update `ACTIVE_TASK.md` when objectives change.
- `MIGRATION_PLAN.md` tracks the CloudKit -> Supabase migration.
