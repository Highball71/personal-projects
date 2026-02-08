//
//  MealSlotView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI

/// A single tappable meal slot (e.g., "Dinner: Spaghetti Bolognese").
/// Shows the meal type label and either the recipe name or a placeholder.
struct MealSlotView: View {
    let mealType: MealType
    let recipeName: String?
    let onTap: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack {
            // Meal type label with fixed width so all slots align
            Text(mealType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            if let recipeName {
                // A recipe is assigned to this slot
                Text(recipeName)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                // X button to clear this slot
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                // Empty slot
                Text("Tap to add")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 4)
        // Makes the entire row tappable, not just the text
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    VStack {
        MealSlotView(mealType: .breakfast, recipeName: "Scrambled Eggs", onTap: {}, onClear: {})
        MealSlotView(mealType: .lunch, recipeName: nil, onTap: {}, onClear: {})
        MealSlotView(mealType: .dinner, recipeName: "Spaghetti Bolognese", onTap: {}, onClear: {})
    }
    .padding()
}
