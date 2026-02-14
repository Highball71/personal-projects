import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }

            Tab("Deeper", systemImage: "eye.trianglebadge.exclamationmark") {
                DeeperTabView()
            }

            Tab("Progress", systemImage: "chart.bar") {
                ProgressTabView()
            }

            Tab("Words", systemImage: "text.book.closed") {
                WordListView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WordProgress.self, DailyActivity.self, EtymologyProgress.self], inMemory: true)
}
