BUILD_SPEC — Fast No Slow WatchOS companion
Status: Ready to build. Next session is the build session. Owner of execution: Claude Code (Swift). Spec authored: 2026-05-28, end of day.


Product intent (David's words)
"I just want to see that heart rate. Any time I look at my watch, the app is up, the number is current, and I never have to relaunch it."

This is a reliability feature first, a watch app second. A pretty UI that sometimes shows a stale number is a failure. A plain UI that always shows the live number is the win.


Scope — what this app IS
A single-screen WatchOS companion that displays:

Heart rate, big, center-screen. Updates live from the iPhone's Polar H10 stream (the phone is the BLE host, not the watch).
Zone color applied to the HR number — the phone's HR-NUMBER color rule (hard zone membership), phone as the single source of truth:
Green — in zone
Red — above zone
Blue — below zone
(The yellow "approaching ceiling" tint that the phone applies to its HR number is a coaching/early-warning concept; it is deliberately NOT mirrored to the watch. The watch shows only the three hard zone states above. See R3 zone-color plumbing.)
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
Note: starting the HKWorkoutSession will spin up the watch's onboard HR sensor for the runtime entitlement. We ignore its values — the Polar-via-phone reading remains the displayed number. Brief moments of divergence between the two sensors are expected and harmless.
R2. Always-On display
Enable Always-On display so the screen never fully blanks during a run. The HR number and zone color stay visible at low refresh between wrist-raises.

The HKWorkoutSession from R1 is what grants BOTH the extended background runtime AND the Always-On frontmost behavior — do NOT use WKExtendedRuntimeSession. It is the wrong API for a workout app and mixes badly with an active workout session; R1 already covers everything WKExtendedRuntimeSession would.
The Always-On dimmed variant is a VIEW concern, not a separate runtime session: read SwiftUI's @Environment(\.isLuminanceReduced) in WatchWorkoutView and render a dimmer, animation-free variant when luminance is reduced.
Acceptable that updates throttle to ~1Hz in Always-On vs. live; what's NOT acceptable is the screen blanking entirely or showing a stale number.
R3. WatchConnectivity push from phone, not pull from watch
Phone is the BLE host (already proven with Polar). State streams phone → watch via WCSession. The iPhone-side WatchConnector from commit 3ae08fa is the foundation; extend, don't rewrite.

updateApplicationContext(_:) is the BACKBONE — it carries HR, the zoneState token, isActive, and timestamp as a single latest-value-wins snapshot, delivered when the watch wakes. That wake-delivery is exactly the wrist-raise reliability requirement, so it is the right primitive for everything. The existing WatchConnector ALREADY uses applicationContext (pushed every ~1s); extend that path, do not replace it.
sendMessage(_:replyHandler:) is OPTIONAL — a low-latency in-flight nicety only when the watch is reachable. It silently drops when the watch is asleep/unreachable, so it must never be the sole path for any field. Not required for v1.
Zone-color plumbing: the phone sends an explicit zoneState token ("inZone"/"aboveZone"/"belowZone") derived from the HR-NUMBER color rule (WorkoutManager.zoneStatus), NOT cueLabel/the coaching banner. The watch renders color directly from the token (inZone→green, aboveZone→red, belowZone→blue) and does NO text-to-color interpretation of its own. Phone is the single source of truth.
On the watch side, treat any snapshot older than ~5s as stale and surface the "waiting"/"reconnecting" indicator.
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
│  WatchConnector            │ ──────────────▶│  WatchWorkoutView      │
│   (from 3ae08fa)           │                │   (HR number + color)  │
└────────────────────────────┘                └────────────────────────┘

iPhone side: extend WatchConnector to push { hr, zoneState, isActive, timestamp } whenever HR or zone changes (already partially scaffolded; flesh out send + state encoding). zoneState is the explicit token "inZone"/"aboveZone"/"belowZone", derived from the phone's HR-NUMBER color rule (WorkoutManager.zoneStatus), NOT from cueLabel/the coaching banner. The current scaffolding sends cueLabel — this session replaces that field with zoneState. Push isActive=false when workout ends.
Watch side: WorkoutMirror (scaffolded in 3ae08fa) receives state and publishes it; WatchWorkoutView renders the single-screen UI; an HKWorkoutSession is started/ended in response to the isActive flag.

The watch never decides anything about zones — it renders the color directly from the zoneState token (inZone→green, aboveZone→red, belowZone→blue). The existing scaffolding's banner-text-to-color mapping in WatchWorkoutView / WorkoutMirror must be REMOVED and replaced with a direct token→color render. Single source of truth: the phone's HR-number color rule.


UI spec
Single view. Vertical layout:

HR number — system font, ~80pt, weight .bold, monospaced digits, color = the zoneState token from the phone (inZone→green, aboveZone→red, belowZone→blue). Centered.
Below it, in .caption2, the literal text "BPM" (or omit if the design reads cleanly without it — Claude Code's call).
A small status pill at the bottom:
Hidden when state is fresh (<5s old) and workout is active.
"Waiting for phone…" when no recent state and no workout active.
"Reconnecting…" when workout active but state is stale (>5s).

Always-On variant: same layout, dimmer colors, no animation, refresh ~1Hz (driven by @Environment(\.isLuminanceReduced)).

Scope discipline: this session STRIPS the coaching banner, cadence/SPM, and elapsed-time that the scaffolded WatchWorkoutView currently renders. The watch shows HR number + zone color + status pill, nothing else.


Build steps (the work, in order)
1. Add the WatchOS app as an actual build target in Fast No Slow.xcodeproj. The Fast No Slow Watch App/ folder already exists from 3ae08fa but is not yet a target — that's step one. Pair it to the iPhone target so it installs together.
2. Signing for the watch app: same team A5DP57PZ7N, bundle ID com.davidalbert.Fast-No-Slow.watchkitapp (confirm against Xcode's auto-generated default, which should be the iPhone app's com.davidalbert.Fast-No-Slow + .watchkitapp).
3. Watch target capabilities/entitlements — PREREQUISITE for HKWorkoutSession, must be done before step 6: add the HealthKit entitlement to the watch target; add NSHealthShareUsageDescription and NSHealthUpdateUsageDescription to the watch Info.plist ("Used to keep the heart-rate display alive during your workout."); enable the "Workout Processing" background mode on the watch target.
4. WatchConnectivity wiring (phone side): extend the WatchConnector applicationContext push. Encode { hr: Int, zoneState: String, isActive: Bool, timestamp: Double }, where zoneState is the token "inZone"/"aboveZone"/"belowZone" derived from WorkoutManager.zoneStatus (the HR-number color rule) — NOT cueLabel. Replace the cueLabel field. Push on each HR/zone change, and isActive=false on workout end.
5. WatchConnectivity receive (watch side): extend WorkoutMirror to decode { hr, zoneState, isActive, timestamp } and publish to SwiftUI. Store the timestamp (currently dropped on the floor) so staleness can be computed in step 8.
6. HKWorkoutSession start/end tied to the isActive flag. Before the first session start, request HealthKit authorization at runtime (HKHealthStore.requestAuthorization) — even though we read/write no samples, the session start fails without it.
7. Always-On display: rely on the HKWorkoutSession (R1) for runtime + Always-On — NO WKExtendedRuntimeSession. In WatchWorkoutView, read @Environment(\.isLuminanceReduced) and render a dimmer, animation-free variant when reduced.
8. Staleness / reconnect logic — from scratch, this plumbing does NOT exist yet: in WorkoutMirror, compare the received timestamp against now and publish a fresh/stale signal. Drive the status pill from it (hidden when fresh + active; "Reconnecting…" when active + stale >5s; "Waiting for phone…" when not active).
9. WatchWorkoutView: the single-screen UI — HR number, zoneState→color, and the status pill. REMOVE the coaching banner, cadence/SPM, and elapsed-time the scaffolded view currently renders (scope discipline). NOTE: the spec previously called this "WatchHRView"; the existing file is WatchWorkoutView — extend that single file, do not add a duplicate.
10. App icon for the watch app (use the phone app icon scaled — Claude Code's call, or flag if none exists).
11. Install to watch. Builds install via the iPhone; the watch app should appear on David's Apple Watch automatically once installed and trusted.
12. Verify on a real run before declaring done.


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
First-install pairing: David's Apple Watch must be paired with his iPhone (it is). The app should install automatically when the iPhone build installs; if it doesn't appear on the watch, the watch needs a manual "Install" tap in the iPhone's Watch app. Flag this if it happens.


Out of scope, but on the future radar
Haptic on zone change (David: "might be more of a distraction than help — hold off"). Easy to add later if he wants it.
Watch start/stop controls.
Standalone watch mode without the phone.
Coaching banner mirror.
Cadence / distance on the watch.

These are all real possible features, but the discipline of this build is "reliability of a single number" first.
