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

                Text("\(formatQuantity(item.totalQuantity)) \(item.unit.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Format quantity cleanly: "2" instead of "2.0", but keep "1.5"
    private func formatQuantity(_ value: Double) -> String {
        if value == value.rounded() && value < 1000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
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
