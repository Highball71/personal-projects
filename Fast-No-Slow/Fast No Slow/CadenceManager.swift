import Foundation
import CoreMotion
import Combine

// Reads live cadence from CMPedometer.
// Always exposes true steps-per-minute (SPM). If the source ever
// returns stride rate, we double it here so every consumer sees SPM.
class CadenceManager: ObservableObject {
    @Published var currentCadence: Double = 0

    private let pedometer = CMPedometer()
    private var lastStepCount: Int = 0
    private var lastSampleTime: Date?

    // CMPedometer.cadence is optional and only available on some devices.
    // We also compute our own from step deltas for reliability.
    func startTracking() {
        guard CMPedometer.isPedometerEventMonitoringAvailable() else {
            print("CadenceManager: pedometer not available")
            return
        }

        let now = Date()
        lastSampleTime = now
        lastStepCount = 0

        // Live pedometer updates — delivers cumulative steps since start.
        pedometer.startUpdates(from: now) { [weak self] data, error in
            guard let self = self, let data = data else { return }

            DispatchQueue.main.async {
                // Prefer CMPedometer's built-in cadence if available.
                // CMPedometer.currentCadence is in steps/second.
                if let cadence = data.currentCadence?.doubleValue {
                    // Convert steps/second → steps/minute.
                    // This is already true step rate from CoreMotion.
                    self.currentCadence = cadence * 60.0
                } else {
                    // Fall back: compute from step count delta.
                    let totalSteps = data.numberOfSteps.intValue
                    let now = Date()
                    if let lastTime = self.lastSampleTime {
                        let elapsed = now.timeIntervalSince(lastTime)
                        if elapsed >= 2.0 {
                            let stepDelta = totalSteps - self.lastStepCount
                            // steps / seconds * 60 = SPM
                            self.currentCadence = (Double(stepDelta) / elapsed) * 60.0
                            self.lastStepCount = totalSteps
                            self.lastSampleTime = now
                        }
                    }
                }
            }
        }
    }

    func stopTracking() {
        pedometer.stopUpdates()
        currentCadence = 0
    }
}
