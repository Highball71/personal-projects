//
//  AppRootView.swift
//  FluffyList
//
//  Root view that gates on onboarding + auth state:
//    1. First launch -> WelcomeSplashView -> HouseholdSetupView (Step 1)
//    2. Not signed in -> SignInView
//    3. Signed in, household lookup loading/failed -> loading/retry
//    4. Signed in, confirmed no household -> HouseholdOnboardingView (create/join)
//    5. Signed in + household -> Tab bar (Meals, Recipes, Grocery, Settings)
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

    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    /// Tracks which onboarding screen to show before the flag is set.
    @State private var onboardingStep: OnboardingStep = .splash

    private enum OnboardingStep {
        case splash
        case householdSetup
    }

    var body: some View {
        Group {
            if let configError = supabaseManager.configError {
                ConfigErrorView(message: configError)
            } else if !hasSeenOnboarding {
                onboardingFlow
            } else {
                sessionGate
            }
        }
        .task {
            // Only check session if we're past onboarding and configured.
            if hasSeenOnboarding && supabaseManager.configError == nil {
                await authService.checkSession()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // A token can expire while backgrounded; re-validate on return so
            // we don't render a logged-in-but-broken app.
            guard newPhase == .active,
                  hasSeenOnboarding,
                  supabaseManager.configError == nil else { return }
            Task { await authService.revalidateOnForeground() }
        }
    }

    /// Routes on the auth-restore state so a returning user sees a brief
    /// "restoring" view instead of a SignInView flash, and a transient
    /// failure offers a retry rather than dumping them at the sign-in wall.
    @ViewBuilder
    private var sessionGate: some View {
        switch authService.sessionState {
        case .restoring:
            AuthRestoringView()
        case .restoreFailed(let message):
            SessionRestoreRetryView(message: message) {
                Task { await authService.checkSession() }
            }
        case .signedOut:
            SignInView()
        case .signedIn:
            householdGate
        }
    }

    @ViewBuilder
    private var householdGate: some View {
        switch supabaseManager.householdMembershipState {
        case .loading:
            HouseholdMembershipLoadingView()
        case .failed(let message):
            HouseholdMembershipRetryView(message: message) {
                Task { await authService.checkSession() }
            }
        case .noHousehold:
            HouseholdOnboardingView()
        case .hasHousehold:
            SupabaseContentView()
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

private struct HouseholdMembershipLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading your household...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
    }
}

/// Shown while we confirm an existing session at launch — prevents the
/// SignInView from flashing in front of an already-signed-in returning user.
private struct AuthRestoringView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Restoring your session…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
    }
}

/// Shown when session restore failed transiently (offline/network). The user
/// is NOT signed out — they can retry once connectivity returns.
private struct SessionRestoreRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Color.fluffySecondary)
            Text("Can't reconnect")
                .font(.headline)
                .foregroundStyle(Color.fluffyPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
    }
}

/// Shown when Supabase configuration is missing/invalid. Recoverable screen
/// instead of a launch crash — tells the developer/user exactly what to fix.
private struct ConfigErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.fluffyError)
            Text("Configuration Problem")
                .font(.fluffyDisplaySmall)
                .foregroundStyle(Color.fluffyPrimary)
            Text(message)
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fluffyBackground)
    }
}

private struct HouseholdMembershipRetryView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("We couldn't load your household.")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry", action: retry)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

/// Main tab bar for the Supabase path, styled for "The Press":
/// paper ground, a 1px ink rule along the top, the active tab in
/// ink 1 (persimmon), inactive tabs in #7D7979, and 10pt uppercase
/// tracked serif labels. No filled pill, no per-tab tint.
struct SupabaseContentView: View {
    @EnvironmentObject private var householdService: HouseholdService
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var authService: AuthService

    /// Meal Plan is the default landing tab — it's the primary
    /// screen for weekly planning.
    @State private var selectedTab: AppTab = .mealPlan

    init() {
        // UITabBar appearance: The Press tab bar. SwiftUI's tabItem
        // can't set fonts/tracking, so this is configured once here.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.fluffyBackground)
        // 1px ink top rule.
        appearance.shadowColor = UIColor(Color.fluffyPrimary)

        let inactive = UIColor(red: 0x7D / 255, green: 0x79 / 255, blue: 0x79 / 255, alpha: 1)
        let active = UIColor(Color.fluffyAccent)
        let labelFont = UIFont(name: FluffyFace.regular, size: 10)
            ?? UIFont.systemFont(ofSize: 10)
        // 0.12em at 10pt = 1.2pt of kern.
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont, .kern: 1.2, .foregroundColor: inactive
        ]
        let selectedAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont, .kern: 1.2, .foregroundColor: active
        ]
        for item in [appearance.stackedLayoutAppearance,
                     appearance.inlineLayoutAppearance,
                     appearance.compactInlineLayoutAppearance] {
            item.normal.iconColor = inactive
            item.normal.titleTextAttributes = normalAttrs
            item.selected.iconColor = active
            item.selected.titleTextAttributes = selectedAttrs
        }
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SupabaseMealPlanView(selectedTab: $selectedTab)
                .tabItem {
                    Label("MEALS", systemImage: "calendar")
                }
                .tag(AppTab.mealPlan)

            SupabaseRecipeListView()
                .tabItem {
                    Label("RECIPES", systemImage: "book")
                }
                .tag(AppTab.recipes)

            SupabaseGroceryListView(selectedTab: $selectedTab)
                .tabItem {
                    Label("GROCERY", systemImage: "cart")
                }
                .tag(AppTab.groceries)

            SupabaseSettingsView()
                .tabItem {
                    Label("SETTINGS", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(Color.fluffyAccent)
        .task {
            await householdService.loadCurrentHousehold()
            await recipeService.fetchRecipes()
        }
    }
}
