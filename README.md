# Personal Projects

iOS apps and tools by David ([Highball71](https://github.com/Highball71)). Built on an M4 iMac using SwiftUI, Claude Code, and Xcode.

## iOS Apps

| App | Status | Description |
|-----|--------|-------------|
| **IntervalTimer** (VoxTimer) | 🟢 Active — TestFlight Build 1 | Work/rest interval timer with voice countdown, haptics, and built-in presets |
| **Family Meal Planner** | 🟢 Active — TestFlight Build 8 | Weekly meal planning with Claude API recipe suggestions and grocery lists |
| **MileageTracker** (Clean Mile) | 🟢 Active — TestFlight Build 2 | Voice-first IRS-compliant mileage tracker with Siri shortcut |
| **WordScene** | ✅ Complete | Vocabulary learning with SM2 spaced repetition and etymology |
| **CareLog** | ⏸️ Inactive | Patient care logging (mileage portion superseded by MileageTracker) |
| **Tralfaz/HQ** | 📋 Planned | Personal dashboard / home automation |
| **Hello World** | ✅ Complete | Proof of life — first iOS app |

## Repo Structure

```
├── ios-apps/          # All Xcode projects
│   ├── CareLog/
│   ├── Family Meal Planner/
│   ├── IntervalTimer/
│   ├── MileageTracker/
│   ├── Tralfaz/
│   ├── WordScene/
│   └── Hello World/
├── tools/             # Utility scripts and web tools
│   ├── autocompare/
│   ├── crm/
│   └── timer/
├── CLAUDE.md          # Claude Code project context and rules
└── PROJECT_HEAP.md    # Detailed status tracker for all projects
```

## Dev Workflow

**Plan** on iPhone/iPad → **Build** on iMac with Claude Code + Xcode → **Ship** to TestFlight → **Review** on GitHub mobile
