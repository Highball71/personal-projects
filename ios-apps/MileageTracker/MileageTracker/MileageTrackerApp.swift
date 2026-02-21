import SwiftUI
import SwiftData

@main
struct MileageTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Trip.self,
            SavedLocation.self,
            OdometerSnapshot.self,
            YearlySettings.self,
        ])
    }
}
