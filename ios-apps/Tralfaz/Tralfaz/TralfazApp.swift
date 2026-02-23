//
//  TralfazApp.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

@main
struct TralfazApp: App {
    // Track whether the app is in the foreground, background, etc.
    @Environment(\.scenePhase) private var scenePhase

    // Only ask for notification permission once (persists in UserDefaults)
    @AppStorage("hasRequestedNotificationPermission")
    private var hasRequestedPermission = false

    init() {
        // Seed sample data on first launch
        let context = SharedModelContainer.instance.mainContext
        SampleData.seedIfNeeded(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Request notification permission on first launch
                .task {
                    if !hasRequestedPermission {
                        await NotificationScheduler.requestPermission()
                        hasRequestedPermission = true
                    }
                }
                // Reschedule all notifications every time the app comes
                // to the foreground, so content stays fresh.
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        let context = sharedModelContainer.mainContext
                        NotificationScheduler.rescheduleAll(modelContext: context)
                    }
                }
        }
        .modelContainer(SharedModelContainer.instance)
    }
}

/// Local-only SwiftData container for the personal CRM.
/// Shared so that both the app and App Intents can access the same store.
enum SharedModelContainer {
    static let instance: ModelContainer = {
        let schema = Schema([
            Contact.self,
            CRMTask.self,
            Appointment.self,
            CRMProject.self
        ])

        let config = ModelConfiguration(
            "Tralfaz",
            schema: schema,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
