import UIKit

// Centralized haptic feedback for workout events.
// Three light taps = chest strap connected
// One warning buzz = sensor disconnected
// Two light taps = 5-min compliance reward
class HapticManager {
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let warning = UINotificationFeedbackGenerator()

    init() {
        impact.prepare()
        warning.prepare()
    }

    /// Three light taps — chest strap connected.
    func chestStrapConnected() {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) { [weak self] in
                self?.impact.impactOccurred()
            }
        }
    }

    /// One warning buzz — sensor disconnected.
    func sensorDisconnected() {
        warning.notificationOccurred(.warning)
    }

    /// Two light taps — 5-minute compliance reward.
    func complianceReward() {
        impact.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.impact.impactOccurred()
        }
    }
}
