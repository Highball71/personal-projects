//
//  DayColumnView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// Displays a single day with its three meal slots (breakfast, lunch, dinner).
/// Today's card gets an accent-colored border and header so it stands out
/// from the rest of the week.
///
/// When the approval flow is active, pending suggestions appear below
/// each meal slot showing who suggested the recipe and (for the Head Cook)
/// approve/reject buttons.
struct DayColumnView: View {
    let date: Date
    let mealPlans: [CDMealPlan]
    let suggestions: [CDMealSuggestion]
    let isHeadCook: Bool
    let approvalFlowActive: Bool
    let onSlotTapped: (MealType) -> Void
    let onSlotCleared: (MealType) -> Void
    let onApproveSuggestion: (CDMealSuggestion) -> Void
    let onRejectSuggestion: (CDMealSuggestion) -> Void

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day header — today shows "Today" with the date, other days show day name
            Text(isToday ? "Today, \(DateHelper.dayMonth(for: date))" : "\(DateHelper.shortDayName(for: date)), \(DateHelper.dayMonth(for: date))")
                .font(.headline)
                .foregroundStyle(isToday ? Color.fluffyAccent : .primary)

            // One slot for each meal type, with suggestions below
            ForEach(MealType.allCases) { mealType in
                let recipe = mealPlans.first(where: { $0.mealTypeRaw == mealType.rawValue })?.recipe
                let slotSuggestions = suggestions.filter { $0.mealTypeRaw == mealType.rawValue }

                VStack(alignment: .leading, spacing: 4) {
                    MealSlotView(
                        mealType: mealType,
                        recipeName: recipe?.name,
                        isToday: isToday,
                        onTap: { onSlotTapped(mealType) },
                        onClear: { onSlotCleared(mealType) }
                    )

                    // Show pending suggestions for this meal slot
                    ForEach(slotSuggestions) { suggestion in
                        SuggestionRowView(
                            suggestion: suggestion,
                            isHeadCook: isHeadCook,
                            onApprove: { onApproveSuggestion(suggestion) },
                            onReject: { onRejectSuggestion(suggestion) }
                        )
                    }
                }
                // On today's card, add a small gap before dinner to
                // separate it from the lighter meals above.
                .padding(.top, isToday && mealType == .dinner ? 4 : 0)
            }
        }
        .padding()
        .background(Color.fluffyCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isToday ? Color.fluffyAccent.opacity(0.5) : Color.fluffyBorder,
                    lineWidth: isToday ? 1.5 : 0.5
                )
        )
    }
}

/// Shows a pending recipe suggestion with who suggested it.
/// The Head Cook sees approve/reject buttons; everyone else just
/// sees the suggestion info.
private struct SuggestionRowView: View {
    let suggestion: CDMealSuggestion
    let isHeadCook: Bool
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Indented to align under the recipe name area
            Spacer()
                .frame(width: 70)

            VStack(alignment: .leading, spacing: 2) {
                if let recipeName = suggestion.recipe?.name {
                    Text(recipeName)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                Text("suggested by \(suggestion.suggestedBy)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isHeadCook {
                // Approve button
                Button(action: onApprove) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)

                // Reject button
                Button(action: onReject) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    DayColumnView(
        date: Date(),
        mealPlans: [],
        suggestions: [],
        isHeadCook: true,
        approvalFlowActive: true,
        onSlotTapped: { _ in },
        onSlotCleared: { _ in },
        onApproveSuggestion: { _ in },
        onRejectSuggestion: { _ in }
    )
    .padding()
    .environment(\.managedObjectContext, NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType))
}
