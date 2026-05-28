import Foundation
import Combine

// MARK: - Data Model

struct CadenceTarget {
    var target: Int    // ideal form (e.g. 170 SPM)
    var floor: Int     // minimum acceptable (e.g. 164 SPM)
}

struct HRGuardrail {
    var low: Int       // zone floor — bring effort up below this
    var high: Int      // zone ceiling — back effort off above this
}

// Which device is providing heart rate data right now.
enum HRSource: Equatable {
    case chestStrap
    case appleWatch
    case unknown
}

// HR-primary coaching state. Each case reflects where HR sits relative
// to the zone. Cadence is intentionally NOT a driver of this state —
// the metronome and the cadence readout in the UI serve as secondary
// rhythm/form guidance only.
enum CoachingCue: Equatable {
    case onTrack    // HR inside the zone
    case hrBelow    // HR below the zone floor — bring effort up
    case hrRising   // HR near the ceiling and trending up — early warning
    case hrAbove    // HR above the ceiling — stronger back-off
}

// One-shot sensor events, separate from coaching cues.
enum SensorAlert: Equatable {
    case connected
    case disconnected
}

// Return type from evaluate().
struct EvaluationResult {
    let cue: CoachingCue
    let voiceMessage: String?     // nil = silence this tick
    let sensorAlert: SensorAlert? // nil = no sensor event
}

// MARK: - Coaching Script (swappable voice phrasing)

/// Maps coaching state to spoken phrasing. Kept as a separate type so
/// the coaching *voice* (tone, personality, verbosity) can be swapped
/// later without touching coaching *decision* logic. For example, a
/// future "grizzled track coach" script would be a new conformer here.
protocol CoachingScript {
    /// Phrase for a cue transition. Return nil for silence.
    func phrase(for cue: CoachingCue) -> String?
    /// Occasional in-zone reassurance. Return nil to disable.
    func reassurance() -> String?
}

struct DefaultCoachingScript: CoachingScript {
    func phrase(for cue: CoachingCue) -> String? {
        switch cue {
        case .onTrack:  return nil                 // silent; reassurance handles in-zone voice
        case .hrBelow:  return "Pick it up."
        case .hrRising: return "Ease up."
        case .hrAbove:  return "Back off."
        }
    }

    func reassurance() -> String? {
        "Right where you want to be."
    }
}

// MARK: - Coaching Engine

/// HR-primary coaching engine.
///
/// Decision hierarchy (evaluated every ~2s):
///   1. HR above ceiling           → hrAbove
///   2. HR near ceiling + rising   → hrRising (predictive warning)
///   3. HR below floor             → hrBelow
///   4. otherwise                  → onTrack
///
/// Voice is gated so the user doesn't feel micromanaged:
///   - onTrack is silent by default; a reassurance phrase is spoken
///     roughly every `reassuranceInterval` of sustained in-zone time.
///   - hrBelow requires HR to be under the floor for at least
///     `sustainedBelowThreshold` before speaking (transient dips stay silent).
///   - All spoken cues share a `cueCooldown` to prevent repetition.
///
/// Cadence is *not* consulted by this engine. The metronome + SPM
/// readout in the UI remain as secondary rhythm/form guidance.
class CoachingEngine: ObservableObject {

    @Published var activeCue: CoachingCue = .onTrack

    // MARK: - Configuration
    var cadenceTarget = CadenceTarget(target: 170, floor: 164)
    var hrGuardrail = HRGuardrail(low: 120, high: 150)

    /// Voice phrasing. Swap to change coaching voice/personality
    /// without touching coaching logic.
    var script: CoachingScript = DefaultCoachingScript()

    // MARK: - HR Rolling Buffer
    private var hrBuffer: [(date: Date, hr: Double)] = []
    private let bufferWindow: TimeInterval = 15

    // MARK: - Evaluation Timing
    private var lastEvaluationTime: Date = .distantPast
    private let evaluationInterval: TimeInterval = 2.0

    // MARK: - Cue Gating
    private var lastCue: CoachingCue?
    private var lastCueTime: Date = .distantPast
    private let cueCooldown: TimeInterval = 15

    /// When the current hrBelow streak began. Used to suppress transient dips.
    private var belowFloorSince: Date?
    private let sustainedBelowThreshold: TimeInterval = 15

    /// When the current onTrack streak began. Used to pace reassurance.
    private var onTrackSince: Date?
    private var lastReassuranceTime: Date = .distantPast
    private let reassuranceInterval: TimeInterval = 240  // ~4 min

    // MARK: - Predictive HR Thresholds
    private let ceilingApproachDelta: Double = 8.0   // "near ceiling" = within 8 bpm
    private let risingTrendThreshold: Double = 3.0   // bpm rise across ~10s

    // MARK: - Computed HR Metrics

    /// Average HR over the last 4 seconds.
    var currentHR: Double {
        let cutoff = Date().addingTimeInterval(-4)
        let recent = hrBuffer.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.hr).reduce(0, +) / Double(recent.count)
    }

    /// Average HR from 8–12 seconds ago.
    var previousHR: Double {
        let now = Date()
        let from = now.addingTimeInterval(-12)
        let to = now.addingTimeInterval(-8)
        let window = hrBuffer.filter { $0.date >= from && $0.date <= to }
        guard !window.isEmpty else { return currentHR }
        return window.map(\.hr).reduce(0, +) / Double(window.count)
    }

    /// Positive = rising, negative = falling.
    var hrTrend: Double { currentHR - previousHR }

    // MARK: - Public API

    func addHeartRate(_ hr: Double) {
        let now = Date()
        hrBuffer.append((date: now, hr: hr))
        let cutoff = now.addingTimeInterval(-bufferWindow)
        hrBuffer.removeAll { $0.date < cutoff }
    }

    /// Main evaluation. Called on every timer tick (~1s). Cadence is
    /// accepted for signature stability but is not consulted for
    /// primary coaching state.
    func evaluate(
        cadence: Double,
        hrSource: HRSource,
        sensorJustDisconnected: Bool,
        sensorJustConnected: Bool
    ) -> EvaluationResult {
        let now = Date()

        // --- Sensor alerts: one-shot, bypass cooldown ---
        if sensorJustDisconnected {
            return EvaluationResult(
                cue: activeCue,
                voiceMessage: "Switched to Apple Watch heart rate.",
                sensorAlert: .disconnected
            )
        }
        if sensorJustConnected {
            return EvaluationResult(
                cue: activeCue,
                voiceMessage: "Chest strap connected.",
                sensorAlert: .connected
            )
        }

        // --- Throttle coaching evaluation to every ~2s ---
        guard now.timeIntervalSince(lastEvaluationTime) >= evaluationInterval else {
            return EvaluationResult(cue: activeCue, voiceMessage: nil, sensorAlert: nil)
        }
        lastEvaluationTime = now

        // --- HR-primary state decision ---
        let hr = currentHR
        let low = Double(hrGuardrail.low)
        let high = Double(hrGuardrail.high)

        let newCue: CoachingCue
        if hr <= 0 {
            // No HR sample yet — hold previous state, say nothing.
            newCue = activeCue
        } else if hr > high {
            newCue = .hrAbove
        } else if hr >= high - ceilingApproachDelta && hrTrend > risingTrendThreshold {
            newCue = .hrRising
        } else if hr < low {
            newCue = .hrBelow
        } else {
            newCue = .onTrack
        }

        // --- Update streak trackers ---
        if newCue == .hrBelow {
            if belowFloorSince == nil { belowFloorSince = now }
        } else {
            belowFloorSince = nil
        }

        if newCue == .onTrack {
            if onTrackSince == nil { onTrackSince = now }
        } else {
            onTrackSince = nil
        }

        activeCue = newCue

        // --- Voice gating ---

        // onTrack is silent, except for occasional reassurance.
        if newCue == .onTrack {
            if let start = onTrackSince,
               now.timeIntervalSince(start) >= reassuranceInterval,
               now.timeIntervalSince(lastReassuranceTime) >= reassuranceInterval {
                lastReassuranceTime = now
                onTrackSince = now   // restart the interval
                return EvaluationResult(
                    cue: newCue,
                    voiceMessage: script.reassurance(),
                    sensorAlert: nil
                )
            }
            return EvaluationResult(cue: newCue, voiceMessage: nil, sensorAlert: nil)
        }

        // Shared cooldown between repeated spoken cues.
        if newCue == lastCue && now.timeIntervalSince(lastCueTime) < cueCooldown {
            return EvaluationResult(cue: newCue, voiceMessage: nil, sensorAlert: nil)
        }

        // Suppress transient hrBelow — wait for a sustained dip.
        if newCue == .hrBelow,
           let start = belowFloorSince,
           now.timeIntervalSince(start) < sustainedBelowThreshold {
            return EvaluationResult(cue: newCue, voiceMessage: nil, sensorAlert: nil)
        }

        lastCue = newCue
        lastCueTime = now

        return EvaluationResult(
            cue: newCue,
            voiceMessage: script.phrase(for: newCue),
            sensorAlert: nil
        )
    }

    /// Reset all state for a new workout.
    func reset() {
        hrBuffer.removeAll()
        lastEvaluationTime = .distantPast
        lastCue = nil
        lastCueTime = .distantPast
        belowFloorSince = nil
        onTrackSince = nil
        lastReassuranceTime = .distantPast
        activeCue = .onTrack
    }
}
