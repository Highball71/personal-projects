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
        let context = sharedModelContainer.mainContext
        SampleData.seedIfNeeded(context: context)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

/// Local-only SwiftData container for the personal CRM.
private let sharedModelContainer: ModelContainer = {
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
