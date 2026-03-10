//
//  Family_Meal_PlannerApp.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData
import CloudKit

// MARK: - App Delegate (CloudKit Share Acceptance)

/// Handles CloudKit share invitations when a household member
/// taps a share link. Accepts the share so SwiftData automatically
/// syncs the shared recipe library to their device.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        // Capture the owner's display name before accepting — available immediately
        // from the metadata without a network call.
        let ownerName: String = {
            guard let components = cloudKitShareMetadata.ownerIdentity.nameComponents else {
                return ""
            }
            return PersonNameComponentsFormatter().string(from: components)
        }()

        if !ownerName.isEmpty {
            // Store for ContentView to pick up on next appear and show a welcome message.
            UserDefaults.standard.set(ownerName, forKey: "pendingWelcomeOwnerName")
        }

        let container = CKContainer(identifier: CloudKitSharingService.containerIdentifier)
        Task {
            do {
                try await container.accept(cloudKitShareMetadata)
                print("[Sync] Accepted household share from \(ownerName.isEmpty ? "unknown" : ownerName)")
            } catch {
                print("[Sync] Failed to accept share: \(error.localizedDescription)")
            }
        }
    }
}

@main
struct Family_Meal_PlannerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var syncMonitor = SyncMonitor()

    init() {
        #if DEBUG
        // Store your Anthropic API key in Keychain on first launch.
        // Replace the placeholder below with your real key, run once,
        // then change it back to the placeholder so you don't commit it.
        let placeholder = "YOUR-KEY-HERE"
        if placeholder != "YOUR-KEY-HERE" {
            try? KeychainHelper.setAnthropicAPIKey(placeholder)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(syncMonitor)
        }
        // SwiftData + CloudKit: syncs recipes, ingredients, and meal plans
        // across all family members via iCloud.
        // Uses .automatic which supports both private and shared CloudKit
        // zones — household members who accept a CKShare see the same data.
        .modelContainer(sharedModelContainer)
    }
}

/// Shared model container — CloudKit-enabled with stable store for data persistence.
/// Uses .automatic to sync via the iCloud container from entitlements.
/// The .automatic scope supports both private and shared CloudKit zones,
/// so household members who accept a CKShare see the same recipes.
///
/// Falls back to local-only storage if CloudKit isn't available
/// (e.g. Simulator, no iCloud account).
private let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Recipe.self,
        Ingredient.self,
        MealPlan.self,
        GroceryItem.self,
        RecipeRating.self,
        HouseholdMember.self,
        MealSuggestion.self
    ])

    // CloudKit-enabled configuration.
    // - Stable name "FamilyMealPlanner" ensures same store across app updates.
    // - isStoredInMemoryOnly: false persists data to disk (prevents wipe on update).
    // - .automatic picks up the CloudKit container from entitlements and
    //   supports both private and shared database scopes.
    do {
        let cloudConfig = ModelConfiguration(
            "FamilyMealPlanner",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        let container = try ModelContainer(for: schema, configurations: [cloudConfig])
        print("[Sync] CloudKit sync enabled")
        return container
    } catch {
        print("[Sync] CloudKit unavailable (\(error.localizedDescription)), falling back to local storage")
    }

    // Fall back to local-only storage so the app never crashes.
    do {
        let localConfig = ModelConfiguration(
            "FamilyMealPlanner",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localConfig])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
