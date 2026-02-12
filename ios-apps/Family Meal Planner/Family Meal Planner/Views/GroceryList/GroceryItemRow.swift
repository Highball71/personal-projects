//
//  GroceryItemRow.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI

/// A single grocery item row with a check-off circle.
/// Checked items get a strikethrough and dimmed appearance.
struct GroceryItemRow: View {
    let item: GroceryItem
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            // Tappable checkmark circle
            Button(action: onToggle) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? .green : .secondary)
                    .imageScale(.large)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading) {
                Text(item.name)
                    .strikethrough(isChecked)
                    .foregroundStyle(isChecked ? .secondary : .primary)

                Text(formatGroceryQuantity(item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Format grocery quantity with fractions and human-readable units.
    /// "to taste" items just show "to taste", "none" unit shows only the quantity.
    private func formatGroceryQuantity(_ item: GroceryItem) -> String {
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
    List {
        GroceryItemRow(
            item: GroceryItem(name: "Flour", totalQuantity: 2, unit: .cup),
            isChecked: false,
            onToggle: {}
        )
        GroceryItemRow(
            item: GroceryItem(name: "Eggs", totalQuantity: 4, unit: .piece),
            isChecked: true,
            onToggle: {}
        )
    }
}
