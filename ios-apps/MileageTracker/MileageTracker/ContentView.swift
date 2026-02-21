import SwiftUI
import SwiftData

/// Root view with tab navigation.
/// Dashboard is the primary tab — shows tax savings and quick-start trip button.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [YearlySettings]
    @Query private var locations: [SavedLocation]

    var body: some View {
        TabView {
            Tab("Dashboard", systemImage: "gauge.with.dots.needle.33percent") {
                DashboardView()
            }

            Tab("Trips", systemImage: "car.fill") {
                TripListView()
            }

            Tab("Locations", systemImage: "mappin.and.ellipse") {
                LocationsView()
            }

            Tab("Reports", systemImage: "doc.text.fill") {
                ReportsView()
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .onAppear {
            seedDefaultsIfNeeded()
        }
    }

    /// Create default settings and locations on first launch.
    private func seedDefaultsIfNeeded() {
        let currentYear = Calendar.current.component(.year, from: Date())
        if settings.isEmpty {
            modelContext.insert(YearlySettings(year: currentYear))
        }
        if locations.isEmpty {
            for location in SavedLocation.defaultLocations {
                modelContext.insert(location)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Trip.self,
            SavedLocation.self,
            OdometerSnapshot.self,
            YearlySettings.self,
        ], inMemory: true)
}
