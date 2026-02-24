//
//  ContentView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// The root view. TabView with three tabs matching the app's three features.
struct ContentView: View {
    var body: some View {
        TabView {
            RecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }

            MealPlanView()
                .tabItem {
                    Label("Meal Plan", systemImage: "calendar")
                }

            GroceryListView()
                .tabItem {
                    Label("Groceries", systemImage: "cart")
                }
        }
        // No sample data seeding — with CloudKit sync, seeding on each
        // device creates duplicates when the cloud copies sync down.
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self, MealSuggestion.self, HouseholdMember.self], inMemory: true)
}
