import AppIntents
import SwiftUI

/// App Intent for "Hey Siri, log mileage" — opens the app directly into the
/// voice-first trip logging flow.
///
/// This uses the iOS 17+ App Intents framework. Users can also add it as a
/// Shortcuts action or create a custom Siri phrase.
struct LogMileageIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mileage"
    static var description: IntentDescription = "Start a voice-guided mileage log entry"

    /// Show the app when this runs — we need the voice flow UI.
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Post a notification that the app should open the voice flow.
        // The DashboardView listens for this and opens VoiceTripFlowView.
        await MainActor.run {
            NotificationCenter.default.post(
                name: .startVoiceTripFlow,
                object: nil
            )
        }
        return .result()
    }
}

/// Provides the shortcut to Siri and the Shortcuts app.
struct MileageTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMileageIntent(),
            phrases: [
                "Log mileage in \(.applicationName)",
                "Start a trip in \(.applicationName)",
                "Log a trip in \(.applicationName)",
            ],
            shortTitle: "Log Mileage",
            systemImageName: "car.fill"
        )
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let startVoiceTripFlow = Notification.Name("startVoiceTripFlow")
}
