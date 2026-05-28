# Active Task

## Just shipped (2026-05-28)
Three features — all built, installed on Dad's iPhone, committed to main:
1. Coach voice picker + new default (Daniel). See STUDIO_LOG.
2. Metronome volume slider (Settings, live).
3. Secondary distance readout near cadence (miles).

## Next Up
- **Real-run verification** (outdoors, GPS): confirm the distance readout
  increments and the metronome volume slider audibly changes a running tick.
  These compiled + installed but weren't exercised on a live run.
- **WatchOS companion (separate session):** `Fast No Slow Watch App/` exists in
  the repo but is **not yet a build target**. Wiring the watch target + HR-on-
  watch is its own task. The iPhone-side watch-mirror (`WatchConnector`) is
  already in place.
- Remaining UX-audit items from the prior list (if still wanted): cadence
  number color, below-zone ring color, drift-vs-too-high voice differentiation,
  stats-grid hierarchy, Live Activity HR color.

## Constraints
- No third-party deps; SwiftUI; iOS 17+ (running fine on iOS 26.5).
- Keep HR primary; don't restyle HR/cadence.
