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
    @Environment(\.modelContext) private var modelContext

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
        .onAppear {
            // Insert sample recipes on first launch so the app isn't empty
            SampleData.insertIfNeeded(into: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
