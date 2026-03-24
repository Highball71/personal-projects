//
//  ContentView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// The root view. TabView with three tabs matching the app's three features.
struct ContentView: View {
    /// Written by AppDelegate when a share invite is accepted.
    /// Read once on appear, then cleared so the welcome shows only once.
    @AppStorage("pendingWelcomeOwnerName") private var pendingWelcomeOwnerName: String = ""

    @State private var showingWelcome = false
    @State private var welcomeOwnerName = ""
    @State private var showingSettings = false

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
        .tint(Color.fluffyAccent)
        // No sample data seeding — with CloudKit sync, seeding on each
        // device creates duplicates when the cloud copies sync down.
        .onAppear {
            // Show a one-time welcome after accepting a household share invite.
            if !pendingWelcomeOwnerName.isEmpty {
                welcomeOwnerName = pendingWelcomeOwnerName
                pendingWelcomeOwnerName = "" // Clear so it only shows once.
                // Brief delay lets the tab view settle before the alert appears.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showingWelcome = true
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Welcome to FluffyList!", isPresented: $showingWelcome) {
            Button("Open Settings") { showingSettings = true }
            Button("Later", role: .cancel) { }
        } message: {
            Text("Welcome to \(welcomeOwnerName)'s FluffyList! Your shared recipes, meal plans, and grocery lists are syncing now.\n\nOpen Settings to tell the app who you are on this device.")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self, MealSuggestion.self, HouseholdMember.self], inMemory: true)
}
