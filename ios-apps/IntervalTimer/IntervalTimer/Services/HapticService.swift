import UIKit

/// Provides haptic feedback at phase transitions during workouts.
class HapticService {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    init() {
        // Pre-warm the generators so there's no delay on first use
        impactGenerator.prepare()
        notificationGenerator.prepare()
    }

    /// Strong haptic for work/rest phase transitions
    func phaseTransition() {
        impactGenerator.impactOccurred()
        impactGenerator.prepare()
    }

    /// Success haptic for workout completion
    func workoutComplete() {
        notificationGenerator.notificationOccurred(.success)
    }
}
