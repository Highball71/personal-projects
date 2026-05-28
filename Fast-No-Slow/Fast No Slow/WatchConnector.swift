import Foundation
import Combine
import WatchConnectivity

/// Pushes live workout state from iPhone to the paired Apple Watch.
///
/// Uses `updateApplicationContext` (latest-value-wins) so the watch
/// always sees the most recent snapshot. No retry logic is needed —
/// if a push fails, the next 1-second tick will overwrite it anyway.
///
/// The iPhone remains the primary workout engine. The watch is a
/// display-only companion; it consumes whatever this class pushes.
final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()

    private var session: WCSession? {
        WCSession.isSupported() ? WCSession.default : nil
    }

    private override init() {
        super.init()
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Push a fresh snapshot of workout state to the watch.
    /// Safe to call every 1s — WC throttles internally.
    func send(
        heartRate: Int,
        cueLabel: String,
        elapsedTime: TimeInterval,
        cadence: Int,
        isPaused: Bool,
        isWorkoutActive: Bool,
        zoneLow: Int,
        zoneHigh: Int,
        targetCadence: Int
    ) {
        guard let session, session.activationState == .activated else { return }
        let payload: [String: Any] = [
            "heartRate": heartRate,
            "cueLabel": cueLabel,
            "elapsedTime": elapsedTime,
            "cadence": cadence,
            "isPaused": isPaused,
            "isWorkoutActive": isWorkoutActive,
            "zoneLow": zoneLow,
            "zoneHigh": zoneHigh,
            "targetCadence": targetCadence,
            "timestamp": Date().timeIntervalSince1970
        ]
        do {
            try session.updateApplicationContext(payload)
        } catch {
            // Non-fatal — the next tick will push a fresh snapshot.
            print("WatchConnector: updateApplicationContext failed: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate (iOS-required stubs)

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {}

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS requires re-activation after deactivate (e.g., user switches watch).
        session.activate()
    }
}
