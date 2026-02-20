import SwiftUI
import SwiftData

@main
struct IntervalTimerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TimerPreset.self)
    }
}
