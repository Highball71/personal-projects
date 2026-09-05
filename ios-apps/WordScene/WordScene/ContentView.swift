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

            Tab("Collection", systemImage: "books.vertical") {
                CollectionView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
