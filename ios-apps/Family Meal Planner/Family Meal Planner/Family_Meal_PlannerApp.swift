//
//  Family_Meal_PlannerApp.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

@main
struct Family_Meal_PlannerApp: App {

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
        }
        // SwiftData + CloudKit: syncs recipes, ingredients, and meal plans
        // across all family members via iCloud.
        // Uses .automatic to pick up the CloudKit container from entitlements.
        .modelContainer(sharedModelContainer)
    }
}

/// Shared model container — tries CloudKit first, falls back to local-only
/// storage if CloudKit isn't available (e.g. Simulator, no iCloud account).
private let sharedModelContainer: ModelContainer = {
    let schema = Schema([Recipe.self, Ingredient.self, MealPlan.self, GroceryItem.self, RecipeRating.self])

    // Try CloudKit-enabled configuration first
    do {
        let cloudConfig = ModelConfiguration(
            "FamilyMealPlanner",
            schema: schema,
            cloudKitDatabase: .automatic
        )
        let container = try ModelContainer(for: schema, configurations: [cloudConfig])
        print("[Sync] CloudKit sync enabled")
        return container
    } catch {
        print("[Sync] CloudKit unavailable (\(error.localizedDescription)), falling back to local storage")
    }

    // Fall back to local-only storage so the app never crashes
    do {
        let localConfig = ModelConfiguration(
            "FamilyMealPlanner",
            schema: schema,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [localConfig])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
