# MileageTracker (Clean Mile)

IRS-compliant mileage tracker for healthcare home office.

## App Details
- Bundle ID: `com.highball71.MileageTracker`
- Native iOS (SwiftUI + SwiftData, iOS 17+)
- TestFlight Build 8

## Key Features
- Voice-first trip logging: app speaks questions, user responds verbally (TTS + SFSpeechRecognizer)
- Two-phase trip flow mirroring actual driving:
  - **Start Trip** (2 questions + auto-confirm): Where are you starting from? → Odometer? → saves in-progress trip
  - **End Trip** (3 questions + voice confirm): Where did you end up? → Ending odometer? → Purpose? → Confirm
- Premium Siri voice TTS with fallback chain (Zoe premium → any premium → enhanced → default)
- Smart odometer parsing: handles spoken digits, English number words, and digit-by-digit dictation (OdometerParser)
- Fully hands-free: auto-advances, spoken readback, voice yes/no confirmation
- Siri shortcuts: "Hey Siri, start a trip" and "Hey Siri, end trip" (App Intents)
- Trip categories: Patient Care, Administrative, Supply Run, Continuing Education, Other
- Saved locations with voice shortcuts and smart frequency learning
- GPS arrival detection for ending odometer prompts (CoreLocation geofencing)
- Quarterly + annual IRS-compliant PDF reports
- Dashboard with running tax savings estimate, in-progress trips with "End Trip" buttons (2026 IRS rate: $0.725/mile)

## Dev Environment
- SSH key (Ed25519) at `~/.ssh/id_ed25519`, added to GitHub, persists via macOS Keychain
- Git: David Albert <david@highball71.com>
- GitHub CLI (`gh`) installed via Homebrew, authenticated as Highball71
- Repo remote uses SSH: `git@github.com:Highball71/personal-projects.git`
