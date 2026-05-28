BUILD_SPEC — Fast No Slow WatchOS companion
Status: Ready to build. Next session is the build session. Owner of execution: Claude Code (Swift). Spec authored: 2026-05-28, end of day.


Product intent (David's words)
"I just want to see that heart rate. Any time I look at my watch, the app is up, the number is current, and I never have to relaunch it."

This is a reliability feature first, a watch app second. A pretty UI that sometimes shows a stale number is a failure. A plain UI that always shows the live number is the win.


Scope — what this app IS
A single-screen WatchOS companion that displays:

Heart rate, big, center-screen. Updates live from the iPhone's Polar H10 stream (the phone is the BLE host, not the watch).
Zone color applied to the HR number, matching the phone exactly:
Green — in zone
Yellow — drifting toward out-of-zone
Red — above zone
Blue — below zone
A small "connected / waiting" indicator so if the link to the phone drops, the user sees it instead of a frozen stale number.

That's it. No banner, no cadence, no distance, no controls. Phone remains the brain. Watch is a dumb glass on the HR + zone.
Scope — what this app is NOT (this session)
No watch-side BLE (Polar pairs to the phone).
No start/stop controls on the watch.
No haptic alerts on zone change (deferred — David's call: "more distraction than help").
No coaching banner mirror.
No HealthKit writes — we're using HealthKit only to keep the workout session alive (see Reliability).
No standalone watch mode — if the phone isn't running a workout, the watch shows "Waiting for phone."


Reliability requirements (the whole point)
Hard requirement: HR must be visible and current on every wrist-raise during a run. No exceptions. No relaunching.

This means the spec uses the following Apple APIs in combination — none are optional:
R1. HKWorkoutSession to keep the app foregrounded
Start an HKWorkoutSession on the watch when a phone-side workout begins, end it when the phone-side workout ends. WatchOS gives workout-session apps extended runtime and prevents the OS from suspending them mid-run. This is the single most important fix for the "app stops working" failure mode David described from another app.

Activity type: .running.
Location type: .outdoor (consistent with the phone's GPS use).
The session is purely to claim foreground runtime — we don't need its metrics; HR comes from the phone via WatchConnectivity.
R2. Always-On display
Enable Always-On display so the screen never fully blanks during a run. The HR number and zone color stay visible at low refresh between wrist-raises.

Implement the appropriate WKExtendedRuntimeSession and Always-On view states; render a slightly dimmed, lower-frequency variant when not active.
Acceptable that updates throttle to ~1Hz in Always-On vs. live; what's NOT acceptable is the screen blanking entirely or showing a stale number.
R3. WatchConnectivity push from phone, not pull from watch
Phone is the BLE host (already proven with Polar). HR streams phone → watch via WCSession.sendMessage or transferUserInfo. The iPhone-side WatchConnector from commit 3ae08fa is the foundation; extend, don't rewrite.

Use sendMessage(_:replyHandler:) for live HR + zone updates (low latency, in-flight).
Use updateApplicationContext(_:) for the "workout active / not active" state (durable, replayed on watch wake).
On the watch side, treat any message older than ~5s as stale and surface the "waiting" indicator.
R4. Reachability handling
If the watch loses connection to the phone (BLE / WCSession), show the "Waiting for phone…" indicator immediately. Do NOT show a stale HR number with no warning — that's the failure mode David called out by name.
R5. Battery trade is accepted
David has explicitly accepted ~15-20% additional battery drain over a one-hour run as the cost of R1 + R2. Don't optimize this away; the reliability is the product.


Architecture
┌────────────────────────────┐                ┌────────────────────────┐
│  iPhone (existing app)     │                │  Apple Watch (NEW)     │
│  ───────────────────────   │                │  ──────────────────    │
│  Polar H10 (BLE)           │                │  HKWorkoutSession      │
│       │                    │                │       │                │
│       ▼                    │   WCSession    │       ▼                │
│  WorkoutManager            │ ◀────────────▶ │  WorkoutMirror         │
│       │                    │   live HR +    │       │                │
│       ▼                    │   zone state   │       ▼                │
│  WatchConnector            │ ──────────────▶│  WatchHRView           │
│   (from 3ae08fa)           │                │   (HR number + color)  │
└────────────────────────────┘                └────────────────────────┘

iPhone side: extend WatchConnector to push { hr, zoneState, isActive } whenever HR or zone changes (already partially scaffolded; flesh out send + state encoding). Push isActive=false when workout ends.
Watch side: WorkoutMirror (scaffolded in 3ae08fa) receives state and publishes it; WatchHRView renders the single-screen UI; an HKWorkoutSession is started/ended in response to the isActive flag.

The watch never decides anything about zones — it just renders what the phone says. Phone is the source of truth for the zone color.


UI spec
Single view. Vertical layout:

HR number — system font, ~80pt, weight .bold, monospaced digits, color = the zone color from the phone. Centered.
Below it, in .caption2, the literal text "BPM" (or omit if the design reads cleanly without it — Claude Code's call).
A small status pill at the bottom:
Hidden when state is fresh (<5s old) and workout is active.
"Waiting for phone…" when no recent state and no workout active.
"Reconnecting…" when workout active but state is stale (>5s).

Always-On variant: same layout, dimmer colors, no animation, refresh ~1Hz.


Build steps (the work, in order)
Add the WatchOS app as an actual build target in Fast No Slow.xcodeproj. The Fast No Slow Watch App/ folder already exists from 3ae08fa but is not yet a target — that's step one. Pair it to the iPhone target so it installs together.
Signing for the watch app: same team A5DP57PZ7N, bundle ID com.highball71.fluffylist.beta.watchkitapp (or current convention — confirm against Xcode's auto-generated default).
WatchConnectivity wiring (phone side): finish the WatchConnector push. Encode { hr: Int, zoneState: String, isActive: Bool, timestamp: Date } and send on each HR update.
WatchConnectivity receive (watch side): flesh out WorkoutMirror to receive, decode, and publish to SwiftUI.
HKWorkoutSession start/end tied to the isActive flag.
Always-On display support and the dimmed variant.
WatchHRView with the HR number, zone color, and status pill.
App icon for the watch app (use the phone app icon scaled — Claude Code's call, or flag if none exists).
Install to watch. Builds install via the iPhone; the watch app should appear on David's Apple Watch automatically once installed and trusted.
Verify on a real run before declaring done.


Acceptance test (David must be able to do this on a real run)
Start a workout on the phone.
Phone speaks the start cue. Watch shows HR + zone color within 5 seconds.
David puts the phone in his pocket and runs.
At any wrist-raise during the run, the HR is current and the color is correct. Not stale. Not blank. Not "tap to relaunch."
When the HR drifts out of zone, the watch number changes color in sync with what the phone is saying.
If David walks out of phone range (~30ft), within 5 seconds the watch shows "Reconnecting…" — not a frozen stale number.
When the workout ends, the watch shows "Waiting for phone…" instead of stale data.

If any of these fails, it's not shipped.


Known unknowns / risks Claude Code should flag, not guess at
App icon: if the watch target's auto-generated icon set is empty, flag it — don't ship without one (Xcode will warn but build).
HealthKit entitlement: required for HKWorkoutSession even though we aren't reading/writing samples. Add to the watch target's entitlements file and to Info.plist as NSHealthShareUsageDescription / NSHealthUpdateUsageDescription with a one-line explanation ("Used to keep the heart-rate display alive during your workout.").
First-install pairing: David's Apple Watch must be paired with his iPhone (it is). The app should install automatically when the iPhone build installs; if it doesn't appear on the watch, the watch needs a manual "Install" tap in the iPhone's Watch app. Flag this if it happens.


Out of scope, but on the future radar
Haptic on zone change (David: "might be more of a distraction than help — hold off"). Easy to add later if he wants it.
Watch start/stop controls.
Standalone watch mode without the phone.
Coaching banner mirror.
Cadence / distance on the watch.

These are all real possible features, but the discipline of this build is "reliability of a single number" first.
