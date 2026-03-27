//
//  GroceryItemRow.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// A single grocery item row with a check-off circle.
/// Checked items get a strikethrough and dimmed appearance.
struct GroceryItemRow: View {
    let item: CDGroceryItem
    let onToggle: () -> Void

    var body: some View {
        HStack {
            // Tappable checkmark circle
            Button(action: onToggle) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isChecked ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading) {
                Text(item.name)
                    .strikethrough(item.isChecked)
                    .foregroundStyle(item.isChecked ? .secondary : .primary)

                Text(formatGroceryQuantity(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Format grocery quantity with fractions and human-readable units.
    /// "to taste" items just show "to taste", "none" unit shows only the quantity.
    private func formatGroceryQuantity(_ item: CDGroceryItem) -> String {
        if item.unit == .toTaste {
            return "to taste"
        }
        let qty = FractionFormatter.formatAsFraction(item.totalQuantity)
        if item.unit == .none {
            return qty
        }
        return "\(qty) \(item.unit.displayName)"
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext

    let item1 = CDGroceryItem(context: context)
    item1.id = UUID()
    item1.itemID = "flour|cup"
    item1.name = "Flour"
    item1.totalQuantity = 2
    item1.unitRaw = IngredientUnit.cup.rawValue
    item1.weekStart = Date()
    item1.isChecked = false

    let item2 = CDGroceryItem(context: context)
    item2.id = UUID()
    item2.itemID = "eggs|piece"
    item2.name = "Eggs"
    item2.totalQuantity = 4
    item2.unitRaw = IngredientUnit.piece.rawValue
    item2.weekStart = Date()
    item2.isChecked = true

    return List {
        GroceryItemRow(item: item1, onToggle: {})
        GroceryItemRow(item: item2, onToggle: {})
    }
}
