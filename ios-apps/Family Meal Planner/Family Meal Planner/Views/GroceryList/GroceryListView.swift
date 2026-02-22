//
//  GroceryListView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Grocery list based on the current week's meal plan.
/// Items are persisted in SwiftData so checked state survives app relaunches.
/// The list is generated from the meal plan once per week and only refreshed
/// when the user explicitly asks or the meal plan changes.
struct GroceryListView: View {
    @Query private var allGroceryItems: [GroceryItem]
    @Query private var allMealPlans: [MealPlan]
    @Environment(\.modelContext) private var modelContext

    @State private var weekStartDate = DateHelper.startOfWeek(containing: Date())
    @State private var showClearConfirmation = false
    @State private var showUncheckConfirmation = false

    /// Persisted grocery items for the current week, sorted alphabetically.
    private var currentWeekItems: [GroceryItem] {
        let weekStart = DateHelper.stripTime(from: weekStartDate)
        return allGroceryItems
            .filter { DateHelper.stripTime(from: $0.weekStart) == weekStart }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Whether any items are currently checked off.
    private var hasCheckedItems: Bool {
        currentWeekItems.contains { $0.isChecked }
    }

    var body: some View {
        NavigationStack {
            Group {
                if currentWeekItems.isEmpty {
                    ContentUnavailableView(
                        "No Groceries Needed",
                        systemImage: "cart",
                        description: Text("Plan some meals first, then your grocery list will appear here")
                    )
                } else {
                    List {
                        ForEach(currentWeekItems) { item in
                            GroceryItemRow(item: item) {
                                toggleCheck(for: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Grocery List")
            .onAppear { generateIfNeeded() }
            .toolbar {
                if !currentWeekItems.isEmpty {
                    Menu {
                        Button("Refresh from Meal Plan", systemImage: "arrow.clockwise") {
                            regenerateFromMealPlan()
                        }

                        if hasCheckedItems {
                            Divider()

                            Button("Uncheck All", systemImage: "arrow.uturn.backward") {
                                showUncheckConfirmation = true
                            }

                            Button("Clear Checked Items", systemImage: "trash", role: .destructive) {
                                showClearConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Clear checked items?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) { clearCheckedItems() }
            } message: {
                Text("This will remove all checked items from the list.")
            }
            .alert("Uncheck all items?", isPresented: $showUncheckConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Uncheck All", role: .destructive) { uncheckAll() }
            } message: {
                Text("This will uncheck all items so you can start a fresh shopping trip.")
            }
        }
    }

    // MARK: - Generation

    /// Generate the grocery list from the meal plan if no items exist for this week.
    private func generateIfNeeded() {
        if currentWeekItems.isEmpty {
            regenerateFromMealPlan()
        }
    }

    /// (Re)generate grocery items from the current week's meal plan.
    /// Preserves checked state for items that still exist.
    private func regenerateFromMealPlan() {
        let weekStart = DateHelper.stripTime(from: weekStartDate)
        let weekDays = DateHelper.weekDays(startingFrom: weekStartDate)
        let dayStarts = Set(weekDays.map { DateHelper.stripTime(from: $0) })

        // Gather this week's meal plan ingredients
        let thisWeekPlans = allMealPlans.filter { plan in
            dayStarts.contains(DateHelper.stripTime(from: plan.date))
        }

        // Combine duplicates: same name + same unit = summed quantity
        var combined: [String: (name: String, qty: Double, unit: IngredientUnit)] = [:]
        for plan in thisWeekPlans {
            guard let recipe = plan.recipe else { continue }
            for ingredient in recipe.ingredientsList {
                let key = "\(ingredient.name.lowercased())|\(ingredient.unit.rawValue)"
                if var existing = combined[key] {
                    existing.qty += ingredient.quantity
                    combined[key] = existing
                } else {
                    combined[key] = (name: ingredient.name, qty: ingredient.quantity, unit: ingredient.unit)
                }
            }
        }

        // Remember which items were checked so we can preserve their state
        let previouslyChecked = Set(currentWeekItems.filter(\.isChecked).map(\.itemID))

        // Delete old items for this week
        for item in currentWeekItems {
            modelContext.delete(item)
        }

        // Insert fresh items, restoring checked state where applicable
        for (key, value) in combined {
            let item = GroceryItem(
                itemID: key,
                name: value.name,
                totalQuantity: value.qty,
                unit: value.unit,
                weekStart: weekStart
            )
            item.isChecked = previouslyChecked.contains(key)
            modelContext.insert(item)
        }

        try? modelContext.save()
    }

    // MARK: - Actions

    /// Toggle a single item's checked state.
    private func toggleCheck(for item: GroceryItem) {
        item.isChecked.toggle()
        try? modelContext.save()
    }

    /// Remove all checked items from the list.
    private func clearCheckedItems() {
        for item in currentWeekItems where item.isChecked {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }

    /// Reset all items to unchecked for a fresh shopping trip.
    private func uncheckAll() {
        for item in currentWeekItems {
            item.isChecked = false
        }
        try? modelContext.save()
    }
}

#Preview {
    GroceryListView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self, GroceryItem.self], inMemory: true)
}
