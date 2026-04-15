//
//  AppRootView.swift
//  FluffyList
//
//  Root view that gates on onboarding + auth state:
//    1. First launch -> WelcomeSplashView -> HouseholdSetupView (Step 1)
//    2. Not signed in -> SignInView
//    3. Signed in, no household -> HouseholdOnboardingView (create/join)
//    4. Signed in + household -> Tab bar (Meals, Recipes, Grocery, Settings)
//
//  This view is used by the Supabase path. The old CloudKit path
//  still goes directly to ContentView from the app entry point.
//

import SwiftUI

/// Shared tab identifier used by SupabaseContentView and child views
/// that need to switch tabs programmatically (e.g. Generate Shopping
/// List in the meal plan switches to the grocery tab).
enum AppTab: Hashable {
    case mealPlan, recipes, groceries, settings
}

struct AppRootView: View {
    @EnvironmentObject private var authService: AuthService
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var supabaseManager: SupabaseManager

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    /// Tracks which onboarding screen to show before the flag is set.
    @State private var onboardingStep: OnboardingStep = .splash

    private enum OnboardingStep {
        case splash
        case householdSetup
    }

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                onboardingFlow
            } else if !authService.isSignedIn {
                SignInView()
            } else if supabaseManager.currentHouseholdID == nil {
                HouseholdOnboardingView()
            } else {
                SupabaseContentView()
            }
        }
        .task {
            // Only check session if we're past onboarding
            if hasSeenOnboarding {
                await authService.checkSession()
            }
        }
    }

    // MARK: - Onboarding Flow

    @ViewBuilder
    private var onboardingFlow: some View {
        switch onboardingStep {
        case .splash:
            WelcomeSplashView {
                withAnimation { onboardingStep = .householdSetup }
            }
            .transition(.opacity)

        case .householdSetup:
            HouseholdSetupView {
                withAnimation {
                    hasSeenOnboarding = true
                }
                // Kick off session check now that onboarding is done
                Task { await authService.checkSession() }
            }
            .transition(.move(edge: .trailing))
        }
    }
}

/// Main tab bar for the Supabase path. Each tab is tinted with its
/// section accent colour: teal for Meals, amber for Recipes, slate
/// blue for Grocery, muted for Settings.
struct SupabaseContentView: View {
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var authService: AuthService

    /// Meal Plan is the default landing tab — it's the primary
    /// screen for weekly planning.
    @State private var selectedTab: AppTab = .mealPlan

    var body: some View {
        TabView(selection: $selectedTab) {
            SupabaseMealPlanView(selectedTab: $selectedTab)
                .tabItem {
                    Label("Meals", systemImage: "calendar")
                }
                .tag(AppTab.mealPlan)

            SupabaseRecipeListView()
                .tabItem {
                    Label("Recipes", systemImage: "book")
                }
                .tag(AppTab.recipes)

            SupabaseGroceryListView()
                .tabItem {
                    Label("Grocery", systemImage: "cart")
                }
                .tag(AppTab.groceries)

            SupabaseSettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(tintColor(for: selectedTab))
        .task {
            await householdService.loadCurrentHousehold()
            await recipeService.fetchRecipes()
        }
    }

    /// Maps each tab to its FluffySection accent colour.
    private func tintColor(for tab: AppTab) -> Color {
        switch tab {
        case .mealPlan:  return .fluffyTeal
        case .recipes:   return .fluffyAmber
        case .groceries: return .fluffySlateBlue
        case .settings:  return .fluffySecondary
        }
    }
}
