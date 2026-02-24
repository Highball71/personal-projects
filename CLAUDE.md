# Project Context

## About
Personal iOS development projects by David (Highball71).
M4 iMac is the development hub. iPhone/iPad used for planning.

## Security Rules
- NEVER read .env files or API keys
- NEVER include API keys, tokens, or secrets in code
- NEVER reference SEHHC, PHI, client names, or patient data
- NEVER commit secrets to Git
- All sensitive credentials live in macOS Keychain

## Architecture Decisions
- All apps use SwiftUI (not UIKit)
- Target iOS 17+
- Use Swift async/await for concurrency
- No third-party dependencies unless necessary
- Local data storage preferred (SwiftData/CoreData)

## Coding Style
- Clear, readable code over clever code
- Explain what you're doing — I'm learning
- Comment non-obvious logic
- Use meaningful variable and function names

## Current Projects
- IntervalTimer (VoxTimer) — active, TestFlight Build 1
- Family Meal Planner — active, TestFlight Build 9, Claude API integration
- MileageTracker (Clean Mile) — active, TestFlight Build 2, voice-first with Siri shortcut
- WordScene — complete
- CareLog — inactive, mileage portion superseded by MileageTracker
- Tralfaz/HQ — planned, personal dashboard rebuild
- Hello World — complete

## How I Work
- Plan features on iPhone/iPad using Apple Notes
- Execute on M4 iMac using Claude Code + Xcode
- Commit and push at end of each session
- Review code on GitHub mobile app
- Use git worktrees for parallel Claude Code sessions
- See PROJECT_HEAP.md for detailed per-app status
