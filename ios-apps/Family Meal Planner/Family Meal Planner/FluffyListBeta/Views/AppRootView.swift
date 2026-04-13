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

    /// Tabs in the order they appear in the tab bar.
    private enum Tab: Hashable {
        case recipes, mealPlan, groceries
    }

    /// Meal Plan is the default landing tab because it's the primary
    /// screen for weekly planning.
    @State private var selectedTab: Tab = .mealPlan

    var body: some View {
        TabView(selection: $selectedTab) {
            SupabaseRecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(Tab.recipes)

            SupabaseMealPlanView()
                .tabItem {
                    Label("Meal Plan", systemImage: "calendar")
                }
                .tag(Tab.mealPlan)

            SupabaseGroceryListView()
                .tabItem {
                    Label("Groceries", systemImage: "cart")
                }
                .tag(Tab.groceries)
        }
        .tint(Color.fluffyAccent)
        .task {
            await householdService.loadCurrentHousehold()
            await recipeService.fetchRecipes()
        }
    }
}
