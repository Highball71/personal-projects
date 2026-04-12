//
//  MealPlanService.swift
//  FluffyList
//
//  CRUD for meal_plans via Supabase.
//  Household-scoped via RLS. One recipe per (household, date) enforced
//  by the unique constraint in migration 004.
//

import Combine
import Foundation
import os
import Supabase

@MainActor
final class MealPlanService: ObservableObject {
    /// Plans for the currently-loaded week, keyed by ISO date string.
    @Published var plansByDate: [String: MealPlanRow] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    /// Formats a Date as an ISO "YYYY-MM-DD" string for Postgres date columns.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    static func isoDate(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    // MARK: - Fetch

    /// Load all meal plans for the 7 days starting at weekStart.
    func fetchPlans(weekStart: Date) async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("fetchPlans: no household ID set")
            plansByDate = [:]
            return
        }

        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let startISO = Self.isoDate(from: weekStart)
        let endISO = Self.isoDate(from: weekEnd)

        Logger.supabase.info("fetchPlans: loading week \(startISO)..<\(endISO) for household \(householdID.uuidString)")
        isLoading = true

        do {
            let rows: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .gte("date", value: startISO)
                .lt("date", value: endISO)
                .execute()
                .value

            var map: [String: MealPlanRow] = [:]
            for row in rows {
                map[row.date] = row
            }
            plansByDate = map

            Logger.supabase.info("fetchPlans: loaded \(rows.count) plan(s)")
            isLoading = false
        } catch {
            Logger.supabase.error("fetchPlans: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Assign

    /// Upsert a meal plan row for (household, date). Replaces any
    /// existing recipe for that day. Returns the meal plan's ID on
    /// success (needed by the caller to record grocery contributions).
    func assignRecipe(recipeID: UUID, on date: Date) async -> UUID? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("assignRecipe: no household ID")
            errorMessage = "No household selected."
            return nil
        }

        let iso = Self.isoDate(from: date)
        Logger.supabase.info("assignRecipe: recipe=\(recipeID.uuidString) date=\(iso)")

        let insert = MealPlanInsert(
            householdID: householdID,
            recipeID: recipeID,
            date: iso
        )

        do {
            let rows: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .upsert(insert, onConflict: "household_id,date")
                .select()
                .execute()
                .value

            guard let row = rows.first else {
                Logger.supabase.error("assignRecipe: upsert returned no rows")
                errorMessage = "Meal plan was not saved."
                return nil
            }

            Logger.supabase.info("assignRecipe: upsert succeeded id=\(row.id.uuidString)")
            return row.id
        } catch {
            Logger.supabase.error("assignRecipe: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Clear

    /// Delete the meal plan row for the given date (if any).
    func clearSlot(on date: Date) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return false }

        let iso = Self.isoDate(from: date)
        Logger.supabase.info("clearSlot: date=\(iso)")

        do {
            try await supabase
                .from("meal_plans")
                .delete()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
                .execute()

            plansByDate.removeValue(forKey: iso)
            Logger.supabase.info("clearSlot: deleted")
            return true
        } catch {
            Logger.supabase.error("clearSlot: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
}
