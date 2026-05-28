# Fast No Slow — Handoff

## Current State
- Working iOS app for HR-based run coaching
- Uses heart rate + cadence (metronome) to guide Zone 2 training
- Bluetooth chest strap HR with Apple Watch fallback
- Metronome for cadence (continuous / guardrail / fade modes)
- Voice cues via AVSpeechSynthesizer for coaching
- Live Activity (Dynamic Island + Lock Screen)
- Hold-to-stop, pause/resume, post-workout summary
- Settings sheet (gear, top-right of Start screen): Coach voice + Metronome volume

## Settings (added 2026-05-28)
Persisted in UserDefaults via `Preferences.swift`. Reached from the gear button
on the Start screen (`SettingsView`).

- **Coach voice** — picker over all `en-*` `AVSpeechSynthesisVoice`s; tap to
  preview ("Pace check") and select. Key `coachVoiceIdentifier`.
  `CoachVoiceStore.resolvedVoice()` is read per-utterance in
  `WorkoutManager.speak()`, so changes apply live with graceful fallback.
  **Default = Daniel** (`...en-GB.Daniel`): stock iPhones ship no good en-US
  male voice (only Fred, robotic); resolver ranks Aaron→Tom→Evan→Nathan→
  Daniel→Arthur→Rishi then any male. Download a premium en-US male in iOS
  Settings to use it instead.
- **Metronome volume** — slider 0–100%, key `metronomeVolume`, default 1.0
  (no change for existing users). Applies live via
  `MetronomeEngine.volumeScale` (multiplied on top of the mode envelope in
  `tick()`); `WorkoutManager.setMetronomeVolume()` persists + forwards.

## Distance readout (added 2026-05-28)
`WorkoutManager.displayDistanceMiles` — miles, refreshed at most ~every 5s in
`timerTick`. Shown small/secondary next to the cadence number in `WorkoutView`
(`formatMiles`: `1.2 mi` under 10, `10.45 mi` at/over). Uses existing
CLLocationManager `totalDistance`; no new location code.

## Coaching Model: HR-primary
The coaching state machine is driven **entirely by heart rate** relative to
the zone guardrail. Cadence is NOT a primary driver — the metronome and the
SPM readout in the UI act as secondary rhythm/form guidance only.

Decision hierarchy (evaluated every 2s, in CoachingEngine.swift):
1. HR > ceiling                          → `hrAbove`
2. HR near ceiling (within 8 bpm) & trend > 3 bpm / 10s → `hrRising`
3. HR < floor                            → `hrBelow`
4. otherwise                             → `onTrack`

User-facing labels (banner + Live Activity):
- **ON TRACK**   (`onTrack`):  green  — HR in zone
- **PICK IT UP** (`hrBelow`):  blue   — HR under floor, bring effort up
- **LIGHTEN UP** (`hrRising`): yellow — HR approaching ceiling & rising
- **EASE EFFORT** (`hrAbove`): red    — HR over ceiling, back off

Note: `ZoneStatus` enum (belowZone/inZone/aboveZone) in WorkoutManager is a
separate, internal HR-membership state used for ring/BPM color and "time in
zone" stats. It does NOT drive the banner text.

## Voice Behavior
Voice phrasing lives in `DefaultCoachingScript` (CoachingEngine.swift) and is
swappable via the `CoachingScript` protocol.

- `hrBelow`  → "Pick it up."       (only after 15s sustained below floor)
- `hrRising` → "Ease up."
- `hrAbove`  → "Back off."
- `onTrack`  → silent, with a reassurance phrase ("Right where you want to
  be.") spoken roughly every 4 min of sustained in-zone time
- 15s cooldown between repeated spoken cues, 2s evaluation interval
- Sensor alerts (chest strap connect/disconnect) bypass cooldown

## Design Philosophy
- Minimal, focused UI — think Apple, not Garmin
- HR is the primary metric (76pt bold, color-coded)
- Clarity at a glance while moving
- No feature creep during UX evaluation phase

## Recent Changes (2026-05-28)
- Added Settings (coach voice picker + metronome volume) and a secondary
  distance readout near cadence. See STUDIO_LOG/2026-05-28-*.
- New default coach voice = Daniel (was falling through to a female voice).
- Committed a large body of prior-session WIP that was sitting uncommitted in
  the tree (HR-primary coaching migration + watch-mirror scaffolding). The
  WatchOS companion is **not yet a build target** and remains a separate
  session — those files are dormant.

## Recent Changes (2026-04-02)
- Fixed visual/voice mismatch: hrDriftingHigh now shows yellow banner + yellow BPM instead of green "IN THE ZONE"
- Fixed BPM color: above-zone = red, below-zone = blue (was white for both)
- Ring stays green during drift (Option B — moderate, not alarm-level)
