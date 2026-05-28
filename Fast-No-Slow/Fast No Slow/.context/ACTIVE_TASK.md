# Active Task

## Just shipped (2026-05-28)
Three features — all built, installed on Dad's iPhone, committed to main:
1. Coach voice picker + new default (Daniel). See STUDIO_LOG.
2. Metronome volume slider (Settings, live).
3. Secondary distance readout near cadence (miles).

## NEXT SESSION — WatchOS companion build
This is the next build. Full spec: **`.context/WATCH_BUILD_SPEC.md`** (read it
first). Goal: a single-screen watch app that always shows the live HR + zone
color from the phone — reliability first.

Foundation already in the repo (committed in `3ae08fa`, but **not yet a build
target**): `Fast No Slow Watch App/` (`...App.swift`, `WatchWorkoutView.swift`,
`WorkoutMirror.swift`) + iPhone-side `WatchConnector.swift`. Step 1 of the spec
is adding the watch target to the Xcode project.

Note: Claude flagged open questions on the spec (zone-color source of truth,
staleness plumbing, sendMessage vs applicationContext, scaffold UI vs spec
scope, a wrong bundle ID). See the session note / pre-build review before
starting — confirm with David, don't guess.

## Secondary follow-up (do after, or alongside)
- **Real-run verification** of this session's iPhone features (outdoors, GPS):
  confirm the distance readout increments and the metronome volume slider
  audibly changes a running tick. Compiled + installed but not yet run live.
- Remaining UX-audit items (if still wanted): cadence number color, below-zone
  ring color, drift-vs-too-high voice differentiation, stats-grid hierarchy,
  Live Activity HR color.

## Constraints
- No third-party deps; SwiftUI; iOS 17+ (running fine on iOS 26.5).
- Keep HR primary; don't restyle HR/cadence.
