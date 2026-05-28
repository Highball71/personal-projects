import Foundation
import WatchConnectivity

/// Receives live workout state pushed from the iPhone and publishes
/// it for the watch UI. This is the watch side of the companion link:
/// no coaching logic, no HR sensor access, no HealthKit — just mirror.
final class WorkoutMirror: NSObject, ObservableObject, WCSessionDelegate {
    @Published var heartRate: Int = 0
    @Published var cueLabel: String = "ON TRACK"
    @Published var elapsedTime: TimeInterval = 0
    @Published var cadence: Int = 0
    @Published var isPaused: Bool = false
    @Published var isWorkoutActive: Bool = false
    @Published var zoneLow: Int = 120
    @Published var zoneHigh: Int = 150
    @Published var targetCadence: Int = 170

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        // On launch, apply the last context the phone pushed so the
        // UI isn't blank while we wait for the next update.
        DispatchQueue.main.async {
            self.apply(session.receivedApplicationContext)
        }
    }

    func session(_ session: WCSession,
                 didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.apply(applicationContext)
        }
    }

    // MARK: - Payload Decoding

    private func apply(_ dict: [String: Any]) {
        guard !dict.isEmpty else { return }
        if let v = dict["heartRate"] as? Int { heartRate = v }
        if let v = dict["cueLabel"] as? String { cueLabel = v }
        if let v = dict["elapsedTime"] as? Double { elapsedTime = v }
        if let v = dict["cadence"] as? Int { cadence = v }
        if let v = dict["isPaused"] as? Bool { isPaused = v }
        if let v = dict["isWorkoutActive"] as? Bool { isWorkoutActive = v }
        if let v = dict["zoneLow"] as? Int { zoneLow = v }
        if let v = dict["zoneHigh"] as? Int { zoneHigh = v }
        if let v = dict["targetCadence"] as? Int { targetCadence = v }
    }
}
