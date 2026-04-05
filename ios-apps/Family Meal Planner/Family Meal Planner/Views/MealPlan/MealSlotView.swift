//
//  MealSlotView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI

/// A single tappable meal slot (e.g., "Dinner: Spaghetti Bolognese").
/// Shows the meal type label and either the recipe name or a placeholder.
///
/// When `isToday` is true and the slot is dinner, the slot gets stronger
/// visual emphasis so the user can quickly see what's for dinner tonight.
struct MealSlotView: View {
    let mealType: MealType
    let recipeName: String?
    var isToday: Bool = false
    let onTap: () -> Void

    /// Tonight's dinner gets special treatment — it's the slot people care about most.
    private var isTonightDinner: Bool {
        isToday && mealType == .dinner
    }

    var body: some View {
        HStack {
            // Meal type label with fixed width so all slots align
            Text(mealType.rawValue)
                .font(.caption)
                .foregroundStyle(isTonightDinner ? Color.fluffyAccent : .secondary)
                .fontWeight(isTonightDinner ? .semibold : .regular)
                .frame(width: 70, alignment: .leading)

            if let recipeName {
                // A recipe is assigned to this slot
                VStack(alignment: .leading, spacing: 1) {
                    Text(recipeName)
                        .font(isTonightDinner ? .body : .subheadline)
                        .fontWeight(isTonightDinner ? .semibold : .regular)
                        .foregroundStyle(isTonightDinner ? Color.fluffyPrimary : .primary)
                        .lineLimit(1)

                    if isTonightDinner {
                        Text("Dinner is set")
                            .font(.caption2)
                            .foregroundStyle(Color.fluffySecondary)
                    }
                }

                Spacer()

                // Chevron signals the row opens an options sheet
                // (Pick a Different Recipe / Surprise Me / Remove from Plan).
                // Replaces the previous X-only control so the tappable
                // area is obvious and the destructive action lives inside
                // the sheet rather than on a tiny icon.
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            } else {
                // Empty slot — tonight's dinner gets a warmer prompt
                if isTonightDinner {
                    Text("What's for dinner?")
                        .font(.subheadline)
                        .foregroundStyle(Color.fluffyAccent.opacity(0.7))
                } else {
                    Text("Tap to add")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
        }
        .padding(.vertical, isTonightDinner ? 6 : 4)
        // Makes the entire row tappable, not just the text
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

#Preview {
    VStack {
        MealSlotView(mealType: .breakfast, recipeName: "Scrambled Eggs", onTap: {})
        MealSlotView(mealType: .lunch, recipeName: nil, onTap: {})
        MealSlotView(mealType: .dinner, recipeName: "Spaghetti Bolognese", isToday: true, onTap: {})
        MealSlotView(mealType: .dinner, recipeName: nil, isToday: true, onTap: {})
    }
    .padding()
}
