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

/// Shared model container configured for CloudKit syncing.
/// Created once at launch — failure is unrecoverable so we fatalError.
private let sharedModelContainer: ModelContainer = {
    let schema = Schema([Recipe.self, Ingredient.self, MealPlan.self])
    let config = ModelConfiguration(
        "FamilyMealPlanner",
        schema: schema,
        cloudKitDatabase: .automatic
    )
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
