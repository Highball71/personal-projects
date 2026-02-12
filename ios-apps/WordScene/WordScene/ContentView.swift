import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Scenarios", systemImage: "theatermasks") {
                ScenarioView()
            }
            Tab("Progress", systemImage: "chart.bar") {
                StatsView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WordProgress.self, inMemory: true)
}
