import Foundation
import Combine

// Which device is providing heart rate data right now.
enum HRSource: Equatable {
    case chestStrap
    case appleWatch
    case unknown
}

// Single active coaching state — only one at a time.
// Higher raw value = higher priority.
enum CoachingState: Int, Comparable, Equatable {
    case stable              = 0
    case cadenceLow          = 1
    case hrTooLow            = 2
    case hrDriftingHigh      = 3
    case hrTooHigh           = 4
    case hrTooHighEscalated  = 5
    case sensorWarning       = 6

    static func < (lhs: CoachingState, rhs: CoachingState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Evaluates HR buffer, cadence, and sensor status to produce a single
// coaching state plus the voice cue to speak (if any).
class CoachingEngine: ObservableObject {

    @Published var activeState: CoachingState = .stable

    // MARK: - Configuration (set by WorkoutManager before workout starts)
    var lowHR: Int = 120
    var highHR: Int = 150
    var targetCadence: Int = 170
    /// How many BPM within ceiling triggers drift warning
    var driftMargin: Double = 5.0
    /// How many seconds above zone before escalation
    var escalationThreshold: TimeInterval = 30
    /// Seconds cadence must be low before cueing
    var cadenceLowDuration: TimeInterval = 5
    /// Cadence tolerance band: target ± this value = "on cadence"
    var cadenceTolerance: Double = 10

    // MARK: - HR Rolling Buffer
    // Stores (timestamp, heartRate) tuples for drift prediction.
    private var hrBuffer: [(date: Date, hr: Double)] = []
    private let bufferWindow: TimeInterval = 15 // keep 15s of data

    // MARK: - State Tracking
    private var aboveZoneSince: Date?
    private var cadenceLowSince: Date?
    private var lastCueState: CoachingState?
    private var lastCueTime: Date = .distantPast
    private let cueCooldown: TimeInterval = 12 // seconds between repeated cues
    private var escalationStep = 0 // 0, 1, 2 for escalating messages

    // MARK: - Computed HR Metrics
    // currentHR = average of last 4 seconds
    var currentHR: Double {
        let cutoff = Date().addingTimeInterval(-4)
        let recent = hrBuffer.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return 0 }
        return recent.map(\.hr).reduce(0, +) / Double(recent.count)
    }

    // previousHR = average of 8–12 seconds ago
    var previousHR: Double {
        let now = Date()
        let from = now.addingTimeInterval(-12)
        let to = now.addingTimeInterval(-8)
        let window = hrBuffer.filter { $0.date >= from && $0.date <= to }
        guard !window.isEmpty else { return currentHR }
        return window.map(\.hr).reduce(0, +) / Double(window.count)
    }

    // hrTrend = positive means rising, negative means falling
    var hrTrend: Double {
        currentHR - previousHR
    }

    // MARK: - Public API

    /// Call every time a new HR sample arrives.
    func addHeartRate(_ hr: Double) {
        let now = Date()
        hrBuffer.append((date: now, hr: hr))
        // Trim buffer to window
        let cutoff = now.addingTimeInterval(-bufferWindow)
        hrBuffer.removeAll { $0.date < cutoff }
    }

    /// Main evaluation. Call on every timer tick (~1s).
    /// Returns a voice cue string if one should be spoken, nil for silence.
    func evaluate(
        cadence: Double,
        hrSource: HRSource,
        sensorJustDisconnected: Bool,
        sensorJustConnected: Bool
    ) -> String? {
        let now = Date()
        let hr = currentHR

        // --- Determine highest-priority state ---

        var newState: CoachingState = .stable

        // Sensor warning: chest strap just disconnected
        if sensorJustDisconnected {
            newState = .sensorWarning
        }

        // HR too high / escalated
        if hr > Double(highHR) {
            if aboveZoneSince == nil {
                aboveZoneSince = now
                escalationStep = 0
            }
            let aboveDuration = now.timeIntervalSince(aboveZoneSince ?? now)
            if aboveDuration >= escalationThreshold {
                newState = max(newState, .hrTooHighEscalated)
            } else {
                newState = max(newState, .hrTooHigh)
            }
        } else {
            aboveZoneSince = nil
            escalationStep = 0
        }

        // HR drifting high: in zone but trending up near ceiling
        if hr >= Double(lowHR) && hr <= Double(highHR) {
            let distanceToCeiling = Double(highHR) - hr
            if distanceToCeiling <= driftMargin && hrTrend > 1.0 {
                newState = max(newState, .hrDriftingHigh)
            }
        }

        // HR too low
        if hr > 0 && hr < Double(lowHR) {
            newState = max(newState, .hrTooLow)
        }

        // Cadence low: only if no higher-priority HR state
        if cadence > 0 && cadence < Double(targetCadence) - cadenceTolerance {
            if cadenceLowSince == nil {
                cadenceLowSince = now
            }
            let lowDuration = now.timeIntervalSince(cadenceLowSince ?? now)
            if lowDuration >= cadenceLowDuration && newState < .cadenceLow {
                newState = max(newState, .cadenceLow)
            }
        } else {
            cadenceLowSince = nil
        }

        // Sensor just connected (lower priority, but always cue)
        if sensorJustConnected {
            activeState = newState
            return "Chest strap connected."
        }

        activeState = newState

        // --- Determine voice cue ---
        // Sensor disconnect always speaks immediately
        if sensorJustDisconnected {
            lastCueState = .sensorWarning
            lastCueTime = now
            return "Heart rate monitor disconnected. Using Apple Watch heart rate."
        }

        // For other states, respect cooldown
        if newState == .stable {
            // Silence is correct when the run is going well
            return nil
        }

        // Don't repeat same cue within cooldown unless state escalated
        if newState == lastCueState && now.timeIntervalSince(lastCueTime) < cueCooldown {
            return nil
        }

        lastCueState = newState
        lastCueTime = now

        switch newState {
        case .hrTooHighEscalated:
            escalationStep += 1
            return escalationStep <= 1 ? "Bring the effort down." : "Back off a little more."
        case .hrTooHigh:
            return "Ease up a bit."
        case .hrDriftingHigh:
            return "Ease up a bit."
        case .hrTooLow:
            return "Pick it up a touch."
        case .cadenceLow:
            return "Quick feet."
        case .sensorWarning:
            return nil // already handled above
        case .stable:
            return nil
        }
    }

    /// Reset all state for a new workout.
    func reset() {
        hrBuffer.removeAll()
        aboveZoneSince = nil
        cadenceLowSince = nil
        lastCueState = nil
        lastCueTime = .distantPast
        escalationStep = 0
        activeState = .stable
    }
}
