//
//  PlannedMealService.swift
//  FluffyList
//
//  CRUD for `meal_plans` rows under the "many meals per day" model.
//  Returns PlannedMeal domain values; decodes PlannedMealRow internally.
//  Household-scoped via RLS.
//
//  No "one recipe per day" assumptions:
//    - fetchPlans returns every row for the week
//    - addPlannedMeal never clears existing rows
//    - deletePlannedMeal removes exactly one row
//
//  Grocery aggregation is handled outside this service.
//

import Combine
import Foundation
import os
import Supabase

@MainActor
final class PlannedMealService: ObservableObject {
    /// All planned meals loaded for the current week, in service-native
    /// order: sort_order ascending, then created_at ascending as a
    /// deterministic tiebreaker. Views/view models are expected to
    /// group and filter as needed.
    @Published var plannedMeals: [PlannedMeal] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    /// Postgres DATE format. Shared with PlannedMealRow so round-trips
    /// match byte-for-byte.
    static func isoDate(from date: Date) -> String {
        PlannedMealRow.dateFormatter.string(from: date)
    }

    // MARK: - Fetch

    /// Load every PlannedMeal in the 7-day window starting at `weekStart`.
    /// Orphan rows (recipe deleted -> recipe_id NULL) and rows with
    /// unparseable dates are dropped.
    func fetchPlans(weekStart: Date) async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("PlannedMeal fetchPlans: no household ID set")
            plannedMeals = []
            return
        }

        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let startISO = Self.isoDate(from: weekStart)
        let endISO = Self.isoDate(from: weekEnd)

        Logger.supabase.info("PlannedMeal fetchPlans: week \(startISO)..<\(endISO) household=\(householdID.uuidString)")
        isLoading = true

        do {
            let rows: [PlannedMealRow] = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .gte("date", value: startISO)
                .lt("date", value: endISO)
                .order("date", ascending: true)
                .order("meal_type", ascending: true)
                .order("sort_order", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value

            let domain = rows.compactMap { $0.toDomain() }
            plannedMeals = domain

            Logger.supabase.info("PlannedMeal fetchPlans: loaded \(rows.count) row(s), \(domain.count) valid")
            isLoading = false
        } catch {
            Logger.supabase.error("PlannedMeal fetchPlans: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Insert

    /// Insert a new planned meal. Does not clear or replace anything —
    /// a day can hold any number of PlannedMeals, and a (date, mealType)
    /// pair can too.
    ///
    /// If `sortOrder` is nil, the new row is placed after existing rows
    /// in the same (date, mealType) by reading the current max.
    ///
    /// Returns the inserted PlannedMeal on success, nil on failure.
    @discardableResult
    func addPlannedMeal(
        recipeID: UUID,
        on date: Date,
        mealType: PlannedMeal.MealType,
        sortOrder: Int? = nil
    ) async -> PlannedMeal? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("PlannedMeal addPlannedMeal: no household ID")
            errorMessage = "No household selected."
            return nil
        }

        let iso = Self.isoDate(from: date)
        let resolvedSortOrder: Int
        if let sortOrder {
            resolvedSortOrder = sortOrder
        } else {
            resolvedSortOrder = await nextSortOrder(
                householdID: householdID,
                iso: iso,
                mealType: mealType
            )
        }

        Logger.supabase.info("PlannedMeal addPlannedMeal: recipe=\(recipeID.uuidString) date=\(iso) type=\(mealType.rawValue) sortOrder=\(resolvedSortOrder)")

        let insert = PlannedMealInsert(
            householdID: householdID,
            recipeID: recipeID,
            date: iso,
            mealType: mealType.rawValue,
            sortOrder: resolvedSortOrder
        )

        do {
            let rows: [PlannedMealRow] = try await supabase
                .from("meal_plans")
                .insert(insert)
                .select()
                .execute()
                .value

            guard let row = rows.first, let meal = row.toDomain() else {
                Logger.supabase.error("PlannedMeal addPlannedMeal: insert returned no usable row")
                errorMessage = "Meal was not saved."
                return nil
            }

            Logger.supabase.info("PlannedMeal addPlannedMeal: inserted id=\(meal.id.uuidString)")
            return meal
        } catch {
            Logger.supabase.error("PlannedMeal addPlannedMeal: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Delete

    /// Remove exactly one PlannedMeal by id. No grocery side-effects —
    /// the caller is responsible for any grocery cleanup in a later phase.
    @discardableResult
    func deletePlannedMeal(_ id: UUID) async -> Bool {
        Logger.supabase.info("PlannedMeal deletePlannedMeal: id=\(id.uuidString)")

        do {
            try await supabase
                .from("meal_plans")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            Logger.supabase.info("PlannedMeal deletePlannedMeal: deleted")
            return true
        } catch {
            Logger.supabase.error("PlannedMeal deletePlannedMeal: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    /// Read the current max sort_order for a (household, date, mealType)
    /// so new rows append after existing ones. Returns 0 on an empty slot.
    private func nextSortOrder(householdID: UUID, iso: String, mealType: PlannedMeal.MealType) async -> Int {
        do {
            let rows: [PlannedMealRow] = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
                .eq("meal_type", value: mealType.rawValue)
                .order("sort_order", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let top = rows.first else { return 0 }
            return top.sortOrder + 1
        } catch {
            Logger.supabase.warning("PlannedMeal nextSortOrder: lookup failed — \(error.localizedDescription); defaulting to 0")
            return 0
        }
    }
}
