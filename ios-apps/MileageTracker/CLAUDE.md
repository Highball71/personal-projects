# MileageTracker (Clean Mile)

IRS-compliant mileage tracker for healthcare home office.

## App Details
- Bundle ID: `com.highball71.MileageTracker`
- Native iOS (SwiftUI + SwiftData, iOS 17+)
- TestFlight Build 2

## Key Features
- Voice-first trip logging: app speaks questions, user responds verbally (TTS + SFSpeechRecognizer)
- 5-step conversational flow: Where are you? → Odometer? → Destination? → Purpose? → Confirm
- Fully hands-free: auto-advances, spoken readback, voice yes/no confirmation
- Siri shortcut: "Hey Siri, log mileage" launches directly into voice flow (App Intents)
- Trip categories: Patient Care, Administrative, Supply Run, Continuing Education, Other
- Saved locations with voice shortcuts and smart frequency learning
- GPS arrival detection for ending odometer prompts (CoreLocation geofencing)
- Quarterly + annual IRS-compliant PDF reports
- Dashboard with running tax savings estimate (2026 IRS rate: $0.725/mile)

## Dev Environment
- SSH key (Ed25519) at `~/.ssh/id_ed25519`, added to GitHub, persists via macOS Keychain
- Git: David Albert <david@highball71.com>
- GitHub CLI (`gh`) installed via Homebrew, authenticated as Highball71
- Repo remote uses SSH: `git@github.com:Highball71/personal-projects.git`
