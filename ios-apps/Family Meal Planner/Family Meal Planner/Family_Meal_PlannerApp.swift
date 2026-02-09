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
        // This sets up the entire SwiftData stack:
        // - Creates a SQLite database on device
        // - Injects it into the SwiftUI environment
        // - All child views can then use @Query and @Environment(\.modelContext)
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self])
    }
}
