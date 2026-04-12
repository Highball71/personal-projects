//
//  ContentView.swift
//  Family Meal Planner
//
//  Root TabView with three tabs: Recipes, Meal Plan, Groceries.
//  Rebuilt for Core Data + CloudKit sharing.
//

import SwiftUI
import CoreData

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

// MARK: - UICloudSharingController SwiftUI Wrapper

import CloudKit
import UIKit

struct CloudSharingView: UIViewControllerRepresentable {
    let controller: UICloudSharingController

    func makeUIViewController(context: Context) -> UICloudSharingController {
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}
