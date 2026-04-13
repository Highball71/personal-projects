//
//  SupabaseGroceryListView.swift
//  FluffyList
//
//  Phase 1 grocery list backed by Supabase.
//  Split into "To Buy" (unchecked) and "Already Got" (checked) sections.
//  Tap to check off, swipe to delete, pull to refresh.
//

import SwiftUI

struct SupabaseGroceryListView: View {
    @EnvironmentObject private var groceryService: GroceryService

    private var uncheckedItems: [SupabaseGroceryItem] {
        groceryService.items.filter { !$0.isChecked }
    }

    private var checkedItems: [SupabaseGroceryItem] {
        groceryService.items.filter { $0.isChecked }
    }

    var body: some View {
        NavigationStack {
            Group {
                if groceryService.isLoading && groceryService.items.isEmpty {
                    ProgressView("Loading groceries...")
                } else if groceryService.items.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                if groceryService.items.contains(where: { $0.isChecked }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear Checked") {
                            Task { await groceryService.clearChecked() }
                        }
                        .foregroundStyle(Color.fluffyAccent)
                    }
                }
            }
            .refreshable {
                await groceryService.fetchItems()
            }
            .task {
                await groceryService.fetchItems()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "cart")
                .font(.system(size: 48))
                .foregroundStyle(Color.fluffySecondary)

            Text("Nothing to buy yet")
                .font(.title3)
                .foregroundStyle(Color.fluffyPrimary)

            Text("Open a recipe and tap\n“Add Ingredients to Grocery List”.")
                .font(.subheadline)
                .foregroundStyle(Color.fluffySecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Item List

    private var itemList: some View {
        List {
            if !uncheckedItems.isEmpty {
                Section("To Buy") {
                    ForEach(uncheckedItems) { item in
                        Button {
                            Task { await groceryService.toggleChecked(item) }
                        } label: {
                            itemRow(item)
                        }
                        .tint(Color.fluffyPrimary)
                    }
                    .onDelete { offsets in
                        Task {
                            for index in offsets {
                                let item = uncheckedItems[index]
                                await groceryService.deleteItem(item.id)
                            }
                        }
                    }
                }
            }

            if !checkedItems.isEmpty {
                Section("Already Got") {
                    ForEach(checkedItems) { item in
                        Button {
                            Task { await groceryService.toggleChecked(item) }
                        } label: {
                            itemRow(item)
                        }
                        .tint(Color.fluffyPrimary)
                    }
                    .onDelete { offsets in
                        Task {
                            for index in offsets {
                                let item = checkedItems[index]
                                await groceryService.deleteItem(item.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func itemRow(_ item: SupabaseGroceryItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.isChecked ? Color.fluffyAccent : Color.fluffySecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(item.isChecked ? Color.fluffySecondary : Color.fluffyPrimary)
                    .strikethrough(item.isChecked, color: Color.fluffySecondary)

                Text(quantityText(item))
                    .font(.caption)
                    .foregroundStyle(Color.fluffySecondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func quantityText(_ item: SupabaseGroceryItem) -> String {
        let qty = FractionFormatter.formatAsFraction(item.quantity)
        if item.unit == IngredientUnit.none.rawValue {
            return qty
        }
        if item.unit == IngredientUnit.toTaste.rawValue {
            return "to taste"
        }
        return "\(qty) \(item.unit)"
    }
}
