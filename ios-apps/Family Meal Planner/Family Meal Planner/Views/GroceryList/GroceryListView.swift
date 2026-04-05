//
//  GroceryListView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// Grocery list based on the current week's meal plan.
/// Items are persisted in Core Data so checked state survives app relaunches.
/// The list is generated from the meal plan once per week and only refreshed
/// when the user explicitly asks or the meal plan changes.
struct GroceryListView: View {
    @FetchRequest(
        entity: CDGroceryItem.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDGroceryItem.name, ascending: true)]
    ) private var allGroceryItems: FetchedResults<CDGroceryItem>

    @FetchRequest(
        entity: CDMealPlan.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDMealPlan.date, ascending: true)]
    ) private var allMealPlans: FetchedResults<CDMealPlan>

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(SyncMonitor.self) private var syncMonitor

    @State private var weekStartDate = DateHelper.startOfWeek(containing: Date())
    @State private var showClearConfirmation = false
    @State private var showUncheckConfirmation = false

    /// Persisted grocery items for the current week, sorted alphabetically.
    private var currentWeekItems: [CDGroceryItem] {
        let weekStart = DateHelper.stripTime(from: weekStartDate)
        return allGroceryItems
            .filter { DateHelper.stripTime(from: $0.weekStart) == weekStart }
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Whether any items are currently checked off.
    private var hasCheckedItems: Bool {
        currentWeekItems.contains { $0.isChecked }
    }

    /// A stable signature of this week's meal plans (date + meal type + recipe).
    /// Drives reactive regeneration: when this value changes — because a recipe
    /// was assigned, replaced, or cleared — SwiftUI fires the `.onChange`
    /// handler on the view and we regenerate the grocery list. Without this,
    /// the list would only refresh on tab appearance, missing some updates.
    ///
    /// Uses the same half-open [weekStart, weekEnd) range check that
    /// regenerateFromMealPlan uses, so the reactive trigger and the actual
    /// regeneration agree on which plans count as "this week".
    private var weekMealPlanSignature: String {
        let weekStart = DateHelper.stripTime(from: weekStartDate)
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else {
            return ""
        }
        return allMealPlans
            .filter { $0.date >= weekStart && $0.date < weekEnd }
            .map { plan -> String in
                let recipeKey = plan.recipe?.objectID.uriRepresentation().absoluteString ?? "nil"
                return "\(plan.date.timeIntervalSince1970)|\(plan.mealTypeRaw)|\(recipeKey)"
            }
            .sorted()
            .joined(separator: ",")
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
                    .scrollContentBackground(.hidden)
                    .background(Color.fluffyBackground)
                }
            }
            .navigationTitle("Grocery List")
            // TEMPORARY DEBUG — remove before release
            .safeAreaInset(edge: .top) {
                Text("DEBUG: Grocery regeneration active")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
            }
            // Offline banner — shown as a persistent inset above the content
            .safeAreaInset(edge: .top) {
                if syncMonitor.isOffline {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.slash")
                            .font(.caption)
                        Text("Offline — changes will sync when connected")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                }
            }
            .onAppear { generateIfNeeded() }
            // Regenerate whenever this week's meal plans change — catches
            // assignments made on another tab without requiring a tab switch.
            .onChange(of: weekMealPlanSignature, initial: false) { _, _ in
                generateIfNeeded()
            }
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
                Text("This will remove all checked items from the list. This clears checkmarks for everyone in your household.")
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

    /// Regenerate the grocery list from the meal plan if it's stale.
    /// "Stale" means the set of (itemID, quantity, unit) derived from
    /// this week's meal plans no longer matches what's on the list —
    /// typically because the user just assigned, cleared, or replaced a
    /// recipe in a meal slot.
    private func generateIfNeeded() {
        regenerateFromMealPlan()
    }

    /// (Re)generate grocery items from the current week's meal plan.
    /// Preserves checked state for items that still exist. Early-outs
    /// when the target list exactly matches the existing one so we don't
    /// churn Core Data (or CloudKit) on every tab switch.
    private func regenerateFromMealPlan() {
        let weekStart = DateHelper.stripTime(from: weekStartDate)
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else {
            return
        }

        // Half-open range [weekStart, weekEnd) — tolerant of any sub-second
        // drift that the earlier Set-based equality check couldn't handle.
        let thisWeekPlans = allMealPlans.filter { plan in
            plan.date >= weekStart && plan.date < weekEnd
        }

        // TEMP DEBUG — remove before release
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fmt.timeZone = TimeZone.current
        print("[TEMP DEBUG] Grocery regen — weekStart=\(fmt.string(from: weekStart)) weekEnd=\(fmt.string(from: weekEnd))")
        print("[TEMP DEBUG] Grocery regen — allMealPlans=\(allMealPlans.count) thisWeek=\(thisWeekPlans.count)")
        // Dump every plan so we can see WHICH ones are being excluded and why.
        for plan in allMealPlans {
            let inRange = plan.date >= weekStart && plan.date < weekEnd
            let marker = inRange ? "IN " : "OUT"
            let recipeName = plan.recipe?.name ?? "<nil recipe>"
            let ingCount = plan.recipe?.ingredientsList.count ?? 0
            print("[TEMP DEBUG]   [\(marker)] plan.date=\(fmt.string(from: plan.date)) type=\(plan.mealTypeRaw) recipe=\"\(recipeName)\" ingredients=\(ingCount)")
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

        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] Grocery regen — combined items=\(combined.count) existing=\(currentWeekItems.count)")

        // Early out if the existing list already matches the target,
        // so we only touch Core Data when there's a real change.
        let existingSignature = Set(currentWeekItems.map { item in
            "\(item.itemID)|\(item.totalQuantity)"
        })
        let targetSignature = Set(combined.map { key, value in
            "\(key)|\(value.qty)"
        })
        if existingSignature == targetSignature {
            // TEMP DEBUG — remove before release
            print("[TEMP DEBUG] Grocery regen — signatures match, early-out")
            return
        }

        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] Grocery regen — writing \(combined.count) items to store")

        // Remember which items were checked so we can preserve their state
        let previouslyChecked = Set(currentWeekItems.filter(\.isChecked).map(\.itemID))

        // Delete old items for this week
        for item in currentWeekItems {
            viewContext.delete(item)
        }

        // Insert fresh items, restoring checked state where applicable
        let householdRequest = CDHousehold.fetchRequest()
        householdRequest.fetchLimit = 1
        let household = (try? viewContext.fetch(householdRequest))?.first

        for (key, value) in combined {
            let item = CDGroceryItem(context: viewContext)
            item.id = UUID()
            item.itemID = key
            item.name = value.name
            item.totalQuantity = value.qty
            item.unitRaw = value.unit.rawValue
            item.weekStart = weekStart
            item.isChecked = previouslyChecked.contains(key)
            item.household = household
        }

        try? viewContext.save()
    }

    // MARK: - Actions

    /// Toggle a single item's checked state.
    private func toggleCheck(for item: CDGroceryItem) {
        item.isChecked.toggle()
        try? viewContext.save()
    }

    /// Remove all checked items from the list.
    private func clearCheckedItems() {
        for item in currentWeekItems where item.isChecked {
            viewContext.delete(item)
        }
        try? viewContext.save()
    }

    /// Reset all items to unchecked for a fresh shopping trip.
    private func uncheckAll() {
        for item in currentWeekItems {
            item.isChecked = false
        }
        try? viewContext.save()
    }
}

#Preview {
    GroceryListView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        .environment(SyncMonitor())
}
