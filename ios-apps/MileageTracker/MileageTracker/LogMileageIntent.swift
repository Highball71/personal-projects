import AppIntents
import SwiftUI

/// App Intent for "Hey Siri, log mileage in Clean Mile" — opens the app
/// directly into the voice-first trip logging flow.
///
/// Uses the iOS 17+ App Intents framework with AppShortcutsProvider so the
/// phrases are registered automatically — no manual Shortcuts setup needed.
struct LogMileageIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Mileage"
    static var description: IntentDescription = IntentDescription(
        "Start a voice-guided mileage log entry for IRS-compliant trip tracking.",
        categoryName: "Tracking"
    )

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

/// Registers shortcut phrases with Siri automatically on app install.
/// The user can say any of these phrases without manually adding a shortcut.
/// \(.applicationName) resolves to CFBundleDisplayName ("Clean Mile").
struct MileageTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMileageIntent(),
            phrases: [
                "Log mileage in \(.applicationName)",
                "Log a trip in \(.applicationName)",
                "Start a trip in \(.applicationName)",
                "Track mileage with \(.applicationName)",
                "Record mileage in \(.applicationName)",
                "Log miles in \(.applicationName)",
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
