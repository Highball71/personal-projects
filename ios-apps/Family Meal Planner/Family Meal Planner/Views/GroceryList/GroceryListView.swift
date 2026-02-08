//
//  GroceryListView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData

/// Auto-generated grocery list based on the current week's meal plan.
/// Collects all ingredients from planned recipes, combines duplicates
/// (e.g., two recipes needing flour → one combined entry), and lets
/// you check items off while shopping.
struct GroceryListView: View {
    @Query private var allMealPlans: [MealPlan]

    // Track checked-off items. This is ephemeral — it resets when you
    // leave the app. Good enough for MVP; could be persisted later.
    @State private var checkedItems: Set<String> = []

    @State private var weekStartDate = DateHelper.startOfWeek(containing: Date())

    /// The main logic: gather ingredients from this week's meals and combine duplicates.
    var groceryItems: [GroceryItem] {
        let weekDays = DateHelper.weekDays(startingFrom: weekStartDate)
        let dayStarts = Set(weekDays.map { DateHelper.stripTime(from: $0) })

        // Filter to just this week's meal plans
        let thisWeekPlans = allMealPlans.filter { plan in
            dayStarts.contains(DateHelper.stripTime(from: plan.date))
        }

        // Combine ingredients: same name + same unit = summed quantity
        // Key example: "flour|cup" combines, but "flour|lb" stays separate
        var combined: [String: GroceryItem] = [:]

        for plan in thisWeekPlans {
            guard let recipe = plan.recipe else { continue }
            for ingredient in recipe.ingredients {
                let key = "\(ingredient.name.lowercased())|\(ingredient.unit.rawValue)"

                if var existing = combined[key] {
                    existing.totalQuantity += ingredient.quantity
                    combined[key] = existing
                } else {
                    combined[key] = GroceryItem(
                        name: ingredient.name,
                        totalQuantity: ingredient.quantity,
                        unit: ingredient.unit
                    )
                }
            }
        }

        return combined.values.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    var body: some View {
        NavigationStack {
            Group {
                if groceryItems.isEmpty {
                    ContentUnavailableView(
                        "No Groceries Needed",
                        systemImage: "cart",
                        description: Text("Plan some meals first, then your grocery list will appear here")
                    )
                } else {
                    List {
                        ForEach(groceryItems) { item in
                            GroceryItemRow(
                                item: item,
                                isChecked: checkedItems.contains(item.id),
                                onToggle: {
                                    if checkedItems.contains(item.id) {
                                        checkedItems.remove(item.id)
                                    } else {
                                        checkedItems.insert(item.id)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Grocery List")
            .toolbar {
                if !groceryItems.isEmpty && !checkedItems.isEmpty {
                    Button("Clear Checks") {
                        checkedItems.removeAll()
                    }
                }
            }
        }
    }
}

/// A computed grocery item — NOT a SwiftData model.
/// This is a value type that exists only for display.
struct GroceryItem: Identifiable {
    var id: String { "\(name.lowercased())|\(unit.rawValue)" }
    let name: String
    var totalQuantity: Double
    let unit: IngredientUnit
}

#Preview {
    GroceryListView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
