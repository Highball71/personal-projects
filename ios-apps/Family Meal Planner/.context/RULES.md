# RULES.md — FluffyList

## Session Rules
- **Do NOT split repos** in this session. Audit only.
- **Do NOT move, rename, or delete** any project files or folders.
- **No work on other projects** this session — FluffyList only.
- **Do NOT design a final brand icon.** The beta icon is temporary.

## Project Rules
- All UI is SwiftUI (never UIKit).
- Target iOS 17+.
- Use Swift async/await for concurrency.
- No third-party dependencies unless absolutely necessary.
- Local data storage uses Core Data + CloudKit.
- Sensitive credentials go in macOS Keychain, never in code.
- Never read or commit `.env` files, API keys, or secrets.

## Naming
- The app's display name on device is **FluffyList Beta**.
- The Xcode project is still called **Family Meal Planner** (historical name).
- The bundle ID is `com.highball71.fluffylist.beta`.
- In code comments and logs, use "FluffyList" (not "Family Meal Planner").

## Context System
- All session state lives in `.context/` directory.
- Update `HANDOFF.md` at end of each session.
- Update `ACTIVE_TASK.md` when objectives change.
- Keep `SESSION_LOG.md` as an execution trail.
- `AI_PROMPT_MAP.md` holds terminology mappings.
- `ARCH_DECISIONS.md` holds architecture decisions.

## CloudKit / Sharing
- Production CloudKit schema is already deployed.
- `aps-environment` is still set to `development` — must flip to `production` before App Store submission.
- Share metadata embeds `CFBundleVersion` at creation time — must match recipient's build.
