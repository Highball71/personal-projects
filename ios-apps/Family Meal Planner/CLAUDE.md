# Family Meal Planner (FluffyList)

**Current Status:** Build 92, TestFlight, pre-App Store

**Tech Stack:**
- SwiftUI (UI)
- Core Data (local persistence)
- CloudKit (cloud sync)
- iOS 17+

**Key Features:**
- Multi-page photo scanning (Claude Vision API via proxy)
- Weekly meal planning
- Per-person recipe ratings
- Grocery list with persistence
- CloudKit sharing (recipient still needs to accept)

**Current Work:**
See `.context/ACTIVE_TASK.md` for what to work on next.

**Repos:**
- App: github.com/Highball71/personal-projects (ios-apps/Family Meal Planner/)
- Proxy: github.com/Highball71/fluffylist-proxy

**Context System:**
All project state lives in `.context/` directory:
- ACTIVE_TASK.md — Current work
- HANDOFF.md — Resume point
- AI_PROMPT_MAP.md — Terminology
- SESSION_LOG.md — Execution trail
- ARCH_DECISIONS.md — Design decisions
