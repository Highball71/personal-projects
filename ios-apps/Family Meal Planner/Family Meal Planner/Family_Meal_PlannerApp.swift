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

    /// The shared persistence controller, injected as an environment object
    /// so views can access the container (and react to container rebuilds
    /// via @Published).
    @StateObject private var persistence = PersistenceController.shared

    /// Single SyncMonitor instance shared across the app.
    @State private var syncMonitor = SyncMonitor()

    var body: some Scene {
        WindowGroup {
            // When a local-store reset is in progress, remove ALL views
            // that hold @FetchRequest from the hierarchy. This prevents
            // stale-object crashes (CDRecipe, CDHouseholdMember, etc.)
            // from the old container being accessed during the rebuild.
            //
            // When isResetting flips back to false, SwiftUI creates
            // fresh ContentView (and all child views) with @FetchRequest
            // instances bound to the NEW container's viewContext.
            if persistence.isResetting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Resetting sync data…")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                ContentView()
                    .environment(
                        \.managedObjectContext,
                        persistence.container.viewContext
                    )
                    .environment(syncMonitor)
                    .environmentObject(persistence)
                    .onAppear {
                        // Ensure a default household exists on first launch.
                        persistence.ensureDefaultHouseholdExists()
                        // Link any orphaned recipes/grocery items to the household.
                        persistence.backfillOrphanedObjects()
                    }
            }
        }
    }
}
