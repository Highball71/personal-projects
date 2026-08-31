//
//  DayPlan.swift
//  FluffyList
//
//  Per-person meals Phase 3: how one day's meal_plans rows group into
//  the week view's day row. Pure data + a pure grouping function so
//  the rendering rules are unit-testable without SwiftUI.
//

import Foundation

/// One day's meals, grouped for rendering:
///   - `householdMeals`: rows with member_id NULL — the whole-family
///     slot. Normally 0 or 1; legacy multi-row slots and meals
///     orphaned by a member delete (the 013 trigger NULLs their
///     member_id) can stack more, and every one is rendered so
///     nothing planned is ever invisible.
///   - `memberMeals`: one entry per member meal, in the household's
///     member order (so the day row lists people consistently).
struct DayPlan: Equatable {
    struct MemberMeal: Equatable {
        let member: HouseholdMemberRow
        let plan: MealPlanRow
    }

    var householdMeals: [MealPlanRow] = []
    var memberMeals: [MemberMeal] = []

    var isEmpty: Bool { householdMeals.isEmpty && memberMeals.isEmpty }
    var mealCount: Int { householdMeals.count + memberMeals.count }

    /// Group one day's rows for rendering.
    ///
    /// Rules:
    ///   - Rows without a recipe (orphaned by a recipe delete) are
    ///     dropped, matching the week view's existing filter.
    ///   - member_id NULL → the household group.
    ///   - member_id that doesn't match any loaded member → ALSO the
    ///     household group. This is the stale-cache window right after
    ///     a member is deleted on another device: the DB trigger has
    ///     already NULLed the row's member_id, our cache just hasn't
    ///     refreshed. Rendering it as a household meal is the sensible
    ///     fallback and matches what the next fetch will show.
    ///   - Member meals are ordered by the members list, not row
    ///     order, so people appear in a stable order day to day.
    static func build(
        from rows: [MealPlanRow],
        members: [HouseholdMemberRow]
    ) -> DayPlan {
        var plan = DayPlan()
        var byMember: [UUID: [MealPlanRow]] = [:]

        for row in rows where row.recipeID != nil {
            if let memberID = row.memberID,
               members.contains(where: { $0.id == memberID }) {
                byMember[memberID, default: []].append(row)
            } else {
                plan.householdMeals.append(row)
            }
        }

        for member in members {
            guard let mealRows = byMember[member.id] else { continue }
            // One meal per (day, member); extra rows are legacy stacks
            // — render them all, same policy as the household group.
            for row in mealRows {
                plan.memberMeals.append(MemberMeal(member: member, plan: row))
            }
        }

        return plan
    }
}
