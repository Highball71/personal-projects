# PROJECT HEAP

Status tracker for all personal iOS projects. Updated 2026-02-22.

---

## IntervalTimer (VoxTimer on App Store Connect) #active
**Work/rest interval timer with voice features**
- Native iOS (SwiftUI + SwiftData, iOS 17+)
- Work/rest interval timer with voice countdown, haptics, background audio
- Voice commands for pause/resume/stop (Speech framework)
- Built-in presets (Tabata 20/10×8, HIIT 40/20×6) plus custom saved presets
- 10-second warning + 5-4-3-2-1 spoken countdown
- Full-screen color-coded phases (red=work, teal=rest, indigo=countdown, green=done)
- Bug fix pass completed (orphaned timer on pause, countdown stopping, elapsed time tracking)
- App icon, accessibility identifiers, launch argument testing support
- Build 1 uploaded to TestFlight
- Bundle ID: `com.highball71.IntervalTimer`

## Family Meal Planner #active
**Weekly meal planning with recipe management and grocery lists**
- Native iOS (SwiftUI + SwiftData, iOS 17+)
- Claude API integration for recipe suggestions
- Recipe search with JSON-LD parsing
- Meal planning, grocery list generation
- 35 production files, 6 test files
- Multiple TestFlight builds shipped (build 9)
- Bundle ID: `com.highball71.Family-Meal-Planner`

## MileageTracker #active
**IRS-compliant mileage tracker for healthcare home office**
- Native iOS (SwiftUI + SwiftData, iOS 17+)
- Home office qualifies as principal place of business — all work trips deductible
- 2026 IRS rate: $0.725/mile
- Voice-first trip logging: app speaks questions, user responds verbally (TTS + SFSpeechRecognizer)
- 5-step conversational flow: Where are you? → Odometer? → Destination? → Purpose? → Confirm
- Fully hands-free: auto-advances through steps, spoken readback, voice yes/no confirmation
- Smart silence timer (4s) resets on each partial result — no more premature cutoffs
- Minimum 4-digit validation for odometer readings keeps listening until complete
- Keyword detection: say "done"/"save" to stop, "yes"/"no" to confirm/restart
- Contextual strings feed location names to recognizer for better accuracy
- Haptic pulse on each new recognition so user knows it's still listening
- Delegate-based TTS completion (accurate timing, no estimated durations)
- "I didn't catch that" auto-retry on failed recognition
- Siri shortcut: "Hey Siri, log mileage" launches directly into voice flow (App Intents)
- Trip categories: Patient Care, Administrative, Supply Run, Continuing Education, Other
- Saved locations with voice shortcuts and smart frequency learning
- GPS arrival detection for ending odometer prompts (CoreLocation geofencing)
- Start/end of year odometer photo capture
- Quarterly + annual IRS-compliant PDF reports with trip detail, tolls, parking
- Weekday reminder notifications
- Dashboard with running tax savings estimate
- App icon (road/mile marker theme)
- Build 2 uploaded to TestFlight (voice overhaul + Siri shortcut)
- Bundle ID: `com.highball71.MileageTracker`

## Tralfaz/HQ #active
**Personal command center / dashboard**
- Web-based prototype lives in `tools/crm/` (single-page `index.html`)
- PWA-ready (apple-mobile-web-app-capable, touch icon)
- Third in iOS rebuild queue

## AutoCompare #complete
**Car insurance cost comparison calculator**
- Web tool in `tools/autocompare/` (single-page `index.html`)

## Timer #complete
**Web-based interval timer**
- Web tool in `tools/timer/` (single-page `index.html`)
- PWA-ready

## WordScene #complete
**Vocabulary learning app with spaced repetition**
- SM2 spaced repetition engine
- Etymology support, 7 word categories
- Session management, streak tracking, calendar heatmap, progress visualization
- 31 Swift source files

## CareLog #inactive
**Patient care logging for healthcare**
- Models: Patient, CareEntry, Shift, Mileage, Templates
- Shift timer, mileage tracking, PDF export
- 27 Swift source files
- Being superseded by Mileage App (for mileage tracking portion)

## Hello World #complete
**Proof of life — first iOS app**
- Minimal SwiftUI app, 2 files
- Done as intended
