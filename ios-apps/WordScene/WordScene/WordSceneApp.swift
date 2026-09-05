import SwiftUI
import SwiftData

@main
struct WordSceneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self])
    }
}
