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
    ///   - Rows without a recipe (orphaned by a recipe delete —
    ///     recipe_id is ON DELETE SET NULL) are KEPT, matching the
    ///     "nothing planned is ever invisible" policy. How such a row
    ///     renders is MealLineState's decision: past rows are quiet
    ///     history ("(recipe deleted)"), live rows ask for attention.
    ///     (They were dropped before 2026-09-06, which made deleted
    ///     recipes vanish from history and hid stale live rows.)
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

        for row in rows {
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

/// How one meal line renders, given whether its recipe resolved and
/// whether the day is past. Pure so the week view and the tests share
/// the same rule.
///
/// A row whose recipe was deleted (recipe_id NULLed by the DB) is two
/// different things depending on the date:
///   - past: plain history. "(recipe deleted)", muted, not tappable —
///     there is nothing for the user to do about last month's dinner.
///   - today or future: a plan slot that still needs a real meal, so
///     it keeps the "MEAL NEEDS ATTENTION" treatment (tap → Replace).
/// A non-nil recipe_id that doesn't resolve locally (recipes not
/// loaded yet, or the stale-cache window right after a delete on
/// another device) always asks for attention — the next fetch settles
/// what it really is.
enum MealLineState: Equatable {
    case recipe
    case deletedHistory
    case needsAttention

    static func forLine(recipeID: UUID?, recipeExists: Bool, isPast: Bool) -> MealLineState {
        if recipeExists { return .recipe }
        if recipeID == nil && isPast { return .deletedHistory }
        return .needsAttention
    }
}
