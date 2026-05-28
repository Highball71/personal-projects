# 2026-05-28 — Settings: coach voice, metronome volume, distance readout

**Builder:** Claude (Opus 4.8). David hands-off; product calls made inline.
**Device:** Dad's iPhone (iOS 26.5). Built Debug, installed, launched, verified.

## What shipped (3 features)

### 1. Coach voice picker + new default
- New `Preferences.swift` → `CoachVoiceStore`: persists the chosen voice
  identifier in UserDefaults and resolves it with graceful fallback.
- Settings → **Coach voice** lists all `en-*` voices (best quality first).
  Tapping a row previews it (speaks "Pace check") and selects it; selection
  persists immediately and is used everywhere coaching speaks.
- `WorkoutManager.speak()` now resolves the voice **per-utterance**, so a
  change in Settings takes effect live with no restart.
- **Default voice picked: Daniel** (`com.apple.voice.super-compact.en-GB.Daniel`).
  - Why not en-US: verified on-device that a stock iPhone has **no**
    premium/enhanced en-US male voice installed. The only en-US voice tagged
    `male` is **Fred** — the robotic legacy voice, unusable as a coach.
  - Resolver ranks known-good males best-first: Aaron → Tom → Evan → Nathan →
    Daniel → Arthur → Rishi, then any en-US male, then any en male. On this
    device that lands on Daniel (reliable, natural, male). If David downloads
    a premium en-US male (e.g. Aaron/Tom) in iOS Settings → Accessibility →
    Spoken Content → Voices, the picker will list it and he can select it.
  - This replaces the old hardcoded `Zach`-then-first-enhanced fallback, which
    is what produced the disliked female voice (it fell through to Samantha-tier).

### 2. Metronome volume slider
- `MetronomeVolumeStore` (UserDefaults, 0...1, **default 1.0** = no change for
  current users — distinguishes "never set" from a deliberate 0.0).
- Settings → **Metronome volume** slider 0–100%. Persists and applies **live**
  via `WorkoutManager.setMetronomeVolume()` → `MetronomeEngine.volumeScale`,
  read in `tick()` and multiplied on top of the existing mode envelope.

### 3. Secondary distance readout
- Shown next to the cadence number in `WorkoutView`, low-emphasis (caption,
  grey). Format: `1.2 mi` under 10, `10.45 mi` at/over.
- Backed by `WorkoutManager.displayDistanceMiles`, refreshed at most every ~5s
  in `timerTick` (the GPS-fed `totalDistance` updates far more often). Uses the
  existing CLLocationManager plumbing — no new location code.
- Note: the 2×2 stats grid already had a "Distance" card; this is an additional
  glanceable readout near cadence, as requested.

## Commits (on main)
1. `3ae08fa` engine layer — voice/volume/distance + **capture in-tree WIP**
2. `5dd1dc4` add Settings screen (coach voice picker + metronome volume)
3. `4686841` prefer Daniel over robotic Fred for default coach voice

## Important: prior-session WIP captured
The working tree arrived with a large body of **uncommitted** prior-session
work, entangled in the same files as my changes:
- Full HR-primary coaching migration in `CoachingEngine.swift` (215 lines) and
  matching banner/zone language in `WorkoutManager`/`WorkoutView`.
- Watch-mirror plumbing: `WatchConnector.swift` + `Fast No Slow Watch App/`.
  **The watch app is not yet a build target** (`xcodebuild -list` shows only the
  iPhone app + LiveActivity extension), so those files are dormant. WatchOS
  HR remains a **separate session** per task scope — I did not work on it,
  only committed the existing files so they aren't lost. `WatchConnector.swift`
  had to be committed because the iPhone target already references it.

I could not split per-feature into individually-compiling commits without these
shared, dependency-chained files, so commit 1 deliberately blends prior WIP +
this session's engine-layer changes, with the breakdown spelled out in its
message. Commit 1's body is the source of truth for "what was already here vs.
what I added."

## Build / verify
- `xcodebuild` Debug → **BUILD SUCCEEDED**, installed via `devicectl`, launched.
- Verified resolved coach voice on device = Daniel (console log).
- Not yet exercised on a live run: metronome volume slider audibly changing a
  running tick, and the distance readout incrementing during a GPS workout —
  worth a quick real-run check next time outdoors.

## Out of scope (left for later)
- WatchOS companion / HR-on-watch (separate session).
- Per-run review of volume + distance behavior during an actual outdoor run.
