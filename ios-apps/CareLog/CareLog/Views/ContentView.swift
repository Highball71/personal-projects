import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Patient> { !$0.isArchived }) private var patients: [Patient]
    @State private var selectedTab = 0
    @State private var hasLoadedTemplates = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Patients / Daily Log
            PatientListView()
                .tabItem {
                    Label("Patients", systemImage: "person.2.fill")
                }
                .tag(0)
            
            // Tab 2: Templates
            TemplateListView()
                .tabItem {
                    Label("Templates", systemImage: "doc.text.fill")
                }
                .tag(1)
            
            // Tab 3: Shift Timer
            ShiftTimerView()
                .tabItem {
                    Label("Shifts", systemImage: "clock.fill")
                }
                .tag(2)
            
            // Tab 4: Mileage
            MileageLogView()
                .tabItem {
                    Label("Mileage", systemImage: "car.fill")
                }
                .tag(3)
            
            // Tab 5: Export / Settings
            ExportSettingsView()
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up.fill")
                }
                .tag(4)
        }
        .tint(AppTheme.primary)
        .onAppear {
            loadDefaultTemplatesIfNeeded()
        }
    }
    
    private func loadDefaultTemplatesIfNeeded() {
        guard !hasLoadedTemplates else { return }
        hasLoadedTemplates = true
        
        // Check if templates exist
        let descriptor = FetchDescriptor<CareTemplate>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        
        if count == 0 {
            for template in CareTemplate.defaultTemplates() {
                modelContext.insert(template)
            }
            try? modelContext.save()
        }
    }
}
