import AppIntents
import SwiftUI

/// App Intent for "Hey Siri, start a trip in Clean Mile" — opens the app
/// directly into the voice-first Start Trip flow.
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
        // Set a UserDefaults flag that DashboardView checks on appear.
        // Works for both cold launch and backgrounded-app scenarios.
        UserDefaults.standard.set(true, forKey: "launchIntoVoiceFlow")
        return .result()
    }
}

/// App Intent for "Hey Siri, end trip in Clean Mile" — opens the app
/// directly into the End Trip flow for the most recent in-progress trip.
struct EndTripIntent: AppIntent {
    static var title: LocalizedStringResource = "End Trip"
    static var description: IntentDescription = IntentDescription(
        "End an in-progress trip with voice-guided destination, odometer, and purpose logging.",
        categoryName: "Tracking"
    )

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "launchIntoEndTripFlow")
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

        AppShortcut(
            intent: EndTripIntent(),
            phrases: [
                "End trip in \(.applicationName)",
                "Finish trip in \(.applicationName)",
                "End my trip in \(.applicationName)",
                "Complete trip in \(.applicationName)",
                "Stop trip in \(.applicationName)",
                "Finish my trip in \(.applicationName)",
            ],
            shortTitle: "End Trip",
            systemImageName: "flag.checkered"
        )
    }
}
