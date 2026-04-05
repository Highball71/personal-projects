import Foundation
import Combine

// MARK: - Data Model

struct CadenceTarget {
    var target: Int    // ideal form (e.g. 170 SPM)
    var floor: Int     // minimum acceptable (e.g. 164 SPM)
}

struct HRGuardrail {
    var low: Int       // lower bound (de-emphasized)
    var high: Int      // upper bound (strongly enforced)
}

// Which device is providing heart rate data right now.
enum HRSource: Equatable {
    case chestStrap
    case appleWatch
    case unknown
}

// Single coaching output — only one at a time.
// Cadence is primary (form), HR is secondary (effort guardrail).
enum CoachingCue: Equatable {
    case increaseCadence   // "Quick feet."
    case holdCadence       // stable — silence
    case lightenStride     // "Lighter, shorter steps."
    case reduceEffort      // "Ease the effort."
}

// One-shot sensor events, separate from coaching cues.
enum SensorAlert: Equatable {
    case connected
    case disconnected
}

// Return type from evaluate().
struct EvaluationResult {
    let cue: CoachingCue
    let voiceMessage: String?     // nil = silence
    let sensorAlert: SensorAlert? // nil = no sensor event
}

// MARK: - Coaching Engine

/// Evaluates cadence and HR to produce a single coaching cue.
/// Cadence is the primary training goal (form).
/// Heart rate is a secondary guardrail (effort).
/// Never solves high HR by encouraging low cadence.
class CoachingEngine: ObservableObject {

    @Published var activeCue: CoachingCue = .holdCadence

    // MARK: - Configuration (set by WorkoutManager before workout starts)
    var cadenceTarget = CadenceTarget(target: 170, floor: 164)
    var hrGuardrail = HRGuardrail(low: 120, high: 150)

    // MARK: - HR Rolling Buffer
    // Stores (timestamp, heartRate) tuples for trend prediction.
    private var hrBuffer: [(date: Date, hr: Double)] = []
    private let bufferWindow: TimeInterval = 15 // keep 15s of data

    // MARK: - Evaluation Timing
    // Coaching evaluates every ~2s even though the timer ticks every 1s.
    private var lastEvaluationTime: Date = .distantPast
    private let evaluationInterval: TimeInterval = 2.0

    // MARK: - Cue Cooldown
    private var lastCue: CoachingCue?
    private var lastCueTime: Date = .distantPast
    private let cueCooldown: TimeInterval = 12 // seconds between repeated cues

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
    var hrTrend: Double {
        currentHR - previousHR
    }

    // MARK: - Public API

    /// Call every time a new HR sample arrives.
    func addHeartRate(_ hr: Double) {
        let now = Date()
        hrBuffer.append((date: now, hr: hr))
        let cutoff = now.addingTimeInterval(-bufferWindow)
        hrBuffer.removeAll { $0.date < cutoff }
    }

    /// Main evaluation. Called on every timer tick (~1s).
    /// Returns an EvaluationResult with the cue, optional voice message, and optional sensor alert.
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
                voiceMessage: "Heart rate monitor disconnected. Using Apple Watch heart rate.",
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

        // --- Gate: only evaluate coaching every ~2 seconds ---
        guard now.timeIntervalSince(lastEvaluationTime) >= evaluationInterval else {
            return EvaluationResult(cue: activeCue, voiceMessage: nil, sensorAlert: nil)
        }
        lastEvaluationTime = now

        // --- Cadence-first coaching logic ---
        let hr = currentHR
        let high = Double(hrGuardrail.high)
        let floor = Double(cadenceTarget.floor)
        let target = Double(cadenceTarget.target)

        var newCue: CoachingCue

        if hr > high {
            // HR over guardrail — respond based on cadence
            if cadence >= floor {
                // Cadence is fine, HR is the problem → lighten stride
                newCue = .lightenStride
            } else {
                // Cadence is also low — don't ask for more steps while HR is high
                newCue = .reduceEffort
            }
        } else if cadence > 0 && cadence < floor {
            // Below cadence floor — needs to pick it up
            newCue = .increaseCadence
        } else if cadence > 0 && cadence < target {
            // Between floor and target — encourage toward target
            newCue = .increaseCadence
        } else {
            // On target (or above) and HR in range — all good
            newCue = .holdCadence
        }

        // Enhancement: predictive — if HR is trending up fast and near ceiling,
        // bias toward lightenStride before HR actually crosses the guardrail
        if hr > high - 8 && hrTrend > 3.0 && cadence >= floor && hr > 0 {
            newCue = .lightenStride
        }

        // Edge case: walking (very low cadence) with high HR — reassure
        if cadence > 0 && cadence < 80 && hr > high {
            activeCue = .holdCadence
            // Always speak this reassurance (bypass cooldown)
            return EvaluationResult(
                cue: .holdCadence,
                voiceMessage: "Stay here — this is expected.",
                sensorAlert: nil
            )
        }

        activeCue = newCue

        // --- Voice cue with cooldown ---
        if newCue == .holdCadence {
            return EvaluationResult(cue: newCue, voiceMessage: nil, sensorAlert: nil)
        }

        // Don't repeat same cue within cooldown
        if newCue == lastCue && now.timeIntervalSince(lastCueTime) < cueCooldown {
            return EvaluationResult(cue: newCue, voiceMessage: nil, sensorAlert: nil)
        }

        lastCue = newCue
        lastCueTime = now

        return EvaluationResult(
            cue: newCue,
            voiceMessage: voiceString(for: newCue),
            sensorAlert: nil
        )
    }

    /// Reset all state for a new workout.
    func reset() {
        hrBuffer.removeAll()
        lastEvaluationTime = .distantPast
        lastCue = nil
        lastCueTime = .distantPast
        activeCue = .holdCadence
    }

    // MARK: - Voice Mapping

    private func voiceString(for cue: CoachingCue) -> String {
        switch cue {
        case .increaseCadence: return "Quick feet."
        case .lightenStride:   return "Lighter, shorter steps."
        case .reduceEffort:    return "Ease the effort."
        case .holdCadence:     return ""
        }
    }
}
