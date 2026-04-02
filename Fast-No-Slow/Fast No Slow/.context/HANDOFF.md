# Fast No Slow — Handoff

## Current State
- Working iOS app for HR-based run coaching
- Uses heart rate + cadence (metronome) to guide Zone 2 training
- Bluetooth chest strap HR with Apple Watch fallback
- Metronome for cadence (continuous / guardrail / fade modes)
- Voice cues via AVSpeechSynthesizer for coaching
- Live Activity (Dynamic Island + Lock Screen)
- Hold-to-stop, pause/resume, post-workout summary

## Color System (WorkoutView)
- **In zone**: green banner, green ring, green BPM
- **Drifting high** (in zone but trending toward ceiling): yellow banner ("EASE UP" + arrow.up.forward icon), yellow BPM, green ring
- **Above zone**: red banner ("SLOW DOWN"), red ring, red BPM
- **Below zone**: blue banner ("SPEED UP"), gray ring, blue BPM
- **Paused**: orange banner

## Coaching Voice Cues
- hrDriftingHigh / hrTooHigh: "Ease up a bit."
- hrTooHighEscalated (>30s above): "Bring the effort down." → "Back off a little more."
- hrTooLow: "Pick it up a touch."
- cadenceLow (5s+ below target-10): "Quick feet."
- 12s cooldown between repeated cues

## Design Philosophy
- Minimal, focused UI — think Apple, not Garmin
- HR is the primary metric (76pt bold, color-coded)
- Clarity at a glance while moving
- No feature creep during UX evaluation phase

## Recent Changes (2026-04-02)
- Fixed visual/voice mismatch: hrDriftingHigh now shows yellow banner + yellow BPM instead of green "IN THE ZONE"
- Fixed BPM color: above-zone = red, below-zone = blue (was white for both)
- Ring stays green during drift (Option B — moderate, not alarm-level)
