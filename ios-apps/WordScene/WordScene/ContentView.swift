import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
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
        .modelContainer(for: [WordProgress.self, DailyActivity.self], inMemory: true)
}
