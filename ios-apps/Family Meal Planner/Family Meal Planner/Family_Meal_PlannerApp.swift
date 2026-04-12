//
//  Family_Meal_PlannerApp.swift
//  Family Meal Planner
//
//  Two paths:
//    - useSupabase = true  -> Supabase Auth + PostgREST (new)
//    - useSupabase = false -> Core Data + CloudKit (old, preserved)
//

import SwiftUI
import CoreData
import CloudKit
import os

// MARK: - Feature Flag

/// Flip this to switch between old CloudKit path and new Supabase path.
/// Once Supabase is validated end-to-end, the CloudKit path can be removed.
private let useSupabase = true

// MARK: - App Delegate (CloudKit Share Acceptance — old path only)

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        guard !useSupabase else { return }  // No-op on Supabase path.

        let persistence = PersistenceController.shared
        let container = persistence.container

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

    // Old CloudKit path — kept but only initialised when needed.
    @StateObject private var persistence = PersistenceController.shared
    @State private var syncMonitor = SyncMonitor()
    @State private var mealPlanningStore = MealPlanningStore()
    private let performStartupReset = false
    @State private var didRunStartupTasks = false

    // New Supabase path
    @StateObject private var supabaseManager = SupabaseManager.shared
    @StateObject private var authService = AuthService()
    @StateObject private var householdService = HouseholdService()
    @StateObject private var recipeService = RecipeService()

    var body: some Scene {
        WindowGroup {
            if useSupabase {
                // ── Supabase path ──
                AppRootView()
                    .environmentObject(supabaseManager)
                    .environmentObject(authService)
                    .environmentObject(householdService)
                    .environmentObject(recipeService)
            } else {
                // ── Old CloudKit path (preserved, not deleted) ──
                Group {
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
                            .environment(mealPlanningStore)
                            .environmentObject(persistence)
                    }
                }
                .task {
                    guard !didRunStartupTasks else { return }
                    didRunStartupTasks = true

                    if performStartupReset {
                        do {
                            try await persistence.resetLocalStoresAndRebuildContainer(syncMonitor: syncMonitor)
                        } catch {
                            print("Reset failed: \(error)")
                        }
                    }

                    persistence.ensureDefaultHouseholdExists()
                    persistence.backfillOrphanedObjects()
                }
            }
        }
    }
}
