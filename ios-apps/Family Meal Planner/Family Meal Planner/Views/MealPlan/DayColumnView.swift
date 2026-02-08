//
//  DayColumnView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI

/// Displays a single day with its three meal slots (breakfast, lunch, dinner).
/// The current day gets a blue header to stand out.
struct DayColumnView: View {
    let date: Date
    let mealPlans: [MealPlan]
    let onSlotTapped: (MealType) -> Void
    let onSlotCleared: (MealType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header, e.g., "Mon, Feb 10"
            // Today's date is highlighted in blue
            Text("\(DateHelper.shortDayName(for: date)), \(DateHelper.dayMonth(for: date))")
                .font(.headline)
                .foregroundStyle(Calendar.current.isDateInToday(date) ? .blue : .primary)

            // One slot for each meal type
            ForEach(MealType.allCases) { mealType in
                let recipe = mealPlans.first(where: { $0.mealType == mealType })?.recipe
                MealSlotView(
                    mealType: mealType,
                    recipeName: recipe?.name,
                    onTap: { onSlotTapped(mealType) },
                    onClear: { onSlotCleared(mealType) }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    DayColumnView(
        date: Date(),
        mealPlans: [],
        onSlotTapped: { _ in },
        onSlotCleared: { _ in }
    )
    .padding()
}
