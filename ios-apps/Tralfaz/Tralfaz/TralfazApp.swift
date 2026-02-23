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
    init() {
        // Seed sample data on first launch
        let context = SharedModelContainer.instance.mainContext
        SampleData.seedIfNeeded(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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
