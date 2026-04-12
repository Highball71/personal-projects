//
//  AppRootView.swift
//  FluffyList
//
//  Root view that gates on auth state:
//    1. Not signed in -> SignInView
//    2. Signed in, no household -> HouseholdOnboardingView
//    3. Signed in + household -> ContentView (existing tabs)
//
//  This view is used by the Supabase path. The old CloudKit path
//  still goes directly to ContentView from the app entry point.
//

import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var supabaseManager: SupabaseManager

    var body: some View {
        Group {
            if !authService.isSignedIn {
                SignInView()
            } else if supabaseManager.currentHouseholdID == nil {
                HouseholdOnboardingView()
            } else {
                SupabaseContentView()
            }
        }
        .task {
            await authService.checkSession()
        }
    }
}

/// A wrapper around the main tab view for the Supabase path.
/// Loads recipes from Supabase instead of Core Data @FetchRequest.
struct SupabaseContentView: View {
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var authService: AuthService

    @State private var showingSettings = false
    @State private var showingAddRecipe = false

    var body: some View {
        TabView {
            // Recipes tab — Supabase-backed
            SupabaseRecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }

            // Placeholder tabs — will be wired up later
            Text("Meal Plan (coming soon)")
                .tabItem {
                    Label("Meal Plan", systemImage: "calendar")
                }

            Text("Groceries (coming soon)")
                .tabItem {
                    Label("Groceries", systemImage: "cart")
                }
        }
        .tint(Color.fluffyAccent)
        .task {
            await householdService.loadCurrentHousehold()
            await recipeService.fetchRecipes()
        }
    }
}
