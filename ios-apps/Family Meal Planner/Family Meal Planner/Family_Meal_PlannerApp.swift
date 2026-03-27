//
//  Family_Meal_PlannerApp.swift
//  Family Meal Planner
//
//  Rebuilt with Core Data + NSPersistentCloudKitContainer.
//  No SwiftData — direct Core Data for reliable CloudKit sharing.
//

import SwiftUI
import CoreData
import CloudKit
import os

// MARK: - App Delegate (CloudKit Share Acceptance)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let persistence = PersistenceController.shared
        let container = persistence.container

        // Accept the share into our shared persistent store.
        container.acceptShareInvitations(
            from: [cloudKitShareMetadata],
            into: persistence.sharedStore!
        ) { metadata, error in
            if let error {
                Logger.cloudkit.error("Failed to accept share: \(error.localizedDescription)")
            } else {
                Logger.cloudkit.info("Accepted household share successfully")
            }
        }
    }
}

@main
struct Family_Meal_PlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(
                    \.managedObjectContext,
                    persistence.container.viewContext
                )
                .environment(SyncMonitor())
        }
    }
}
