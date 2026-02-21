# PROJECT HEAP

Status tracker for all personal iOS projects. Updated 2026-02-21.

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
- Multiple TestFlight builds shipped (build 8)
- Bundle ID: `com.highball71.Family-Meal-Planner`

## Mileage App #planned
**IRS-compliant mileage tracker for healthcare home office**
- Full IRS deep dive completed — home office qualifies as principal place of business
- All trips from home office to Pittsburgh office, Joey's house, and patient locations are deductible
- 2026 rate: $0.725/mile
- Voice-first design: app asks where you are, odometer, destination, purpose
- GPS arrival detection for ending odometer prompt
- Start/end of year odometer photo capture
- Quarterly + annual IRS-compliant PDF reports
- Smart location learning over time
- Second in rebuild queue (after IntervalTimer)

## Tralfaz/HQ #planned
**Home automation / personal dashboard**
- Third in rebuild queue
- Details TBD

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
