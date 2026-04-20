//
//  MealPlanService.swift
//  FluffyList
//
//  CRUD for meal_plans via Supabase.
//  Household-scoped via RLS.
//
//  Slot rule (Beta): one meal per (household, date). The DB still
//  permits multiple rows per slot — the rule is enforced in the app
//  by the assign path, which clears the slot before inserting.
//  Legacy multi-row slots are tolerated on read and collapsed on the
//  next assign or remove.
//

import Combine
import Foundation
import os
import Supabase

@MainActor
final class MealPlanService: ObservableObject {
    /// Plans for the currently-loaded week, keyed by ISO date string.
    /// Each date maps to an array of meal plan rows (multi-meal per day).
    @Published var plansByDate: [String: [MealPlanRow]] = [:]
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

            var map: [String: [MealPlanRow]] = [:]
            for row in rows {
                map[row.date, default: []].append(row)
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

    // MARK: - Add Meal

    /// Insert a new meal plan row for (household, date).
    /// Multiple rows per date are allowed.
    func addMeal(recipeID: UUID, on date: Date) async -> UUID? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("addMeal: no household ID")
            errorMessage = "No household selected."
            return nil
        }

        let iso = Self.isoDate(from: date)
        Logger.supabase.info("addMeal: recipe=\(recipeID.uuidString) date=\(iso)")

        let insert = MealPlanInsert(
            householdID: householdID,
            recipeID: recipeID,
            date: iso
        )

        do {
            let rows: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .insert(insert)
                .select()
                .execute()
                .value

            guard let row = rows.first else {
                Logger.supabase.error("addMeal: insert returned no rows")
                errorMessage = "Meal plan was not saved."
                return nil
            }

            Logger.supabase.info("addMeal: inserted id=\(row.id.uuidString)")
            return row.id
        } catch {
            Logger.supabase.error("addMeal: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Assign Meal + Groceries (orchestration)

    /// Assign a recipe to a slot (household, date), enforcing the
    /// one-meal-per-slot rule:
    ///   1. Clear the slot — delete any existing meal_plans rows for
    ///      this date and undo their grocery contributions
    ///   2. Insert the new meal plan row
    ///   3. Fetch the recipe's ingredients
    ///   4. Insert them as grocery items with contribution tracking
    ///
    /// This is the single write path for meal assignment from any UI
    /// surface (meal plan view, recipe list, recipe detail). Calling
    /// it on an empty slot is just an insert; calling it on a filled
    /// slot is a clean replace.
    ///
    /// Returns the new meal plan ID on success, nil on failure.
    func addMealWithGroceries(
        recipe: RecipeRow,
        on date: Date,
        recipeService: RecipeService,
        groceryService: GroceryService
    ) async -> UUID? {
        // Guard: don't allow assigning meals to past dates.
        if Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date()) {
            Logger.supabase.warning("addMealWithGroceries: blocked — date \(Self.isoDate(from: date)) is in the past")
            errorMessage = "You can only plan meals for today or future days."
            return nil
        }

        // 1. Clear the slot first so this date holds at most one meal
        //    after we insert. Safe on an already-empty slot.
        //
        //    CRITICAL: if the clear fails (silent RLS rejection, network
        //    error, etc.) we MUST NOT proceed with the insert. Doing so
        //    would leave the slot stacked (old + new) and double the
        //    grocery contributions. errorMessage is already set by
        //    clearDayWithGroceries on failure.
        let cleared = await clearDayWithGroceries(on: date, groceryService: groceryService)
        guard cleared else {
            Logger.supabase.error("addMealWithGroceries: aborting insert — slot clear failed for date=\(Self.isoDate(from: date))")
            return nil
        }

        // 2. Insert meal plan row
        guard let newPlanID = await addMeal(recipeID: recipe.id, on: date) else {
            return nil
        }

        // 3. Fetch the recipe's ingredients
        let ingredients = await recipeService.fetchIngredients(for: recipe.id)
        Logger.supabase.info("addMealWithGroceries: fetched \(ingredients.count) ingredient(s)")

        // 4. Insert grocery items with contributions
        if !ingredients.isEmpty, let householdID = SupabaseManager.shared.currentHouseholdID {
            let inserts = ingredients
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { ing in
                    GroceryItemInsert(
                        householdID: householdID,
                        name: ing.name,
                        quantity: ing.quantity,
                        unit: ing.unit
                    )
                }
            _ = await groceryService.addItemsForMealPlan(mealPlanID: newPlanID, items: inserts)
        }

        return newPlanID
    }

    // MARK: - Remove Single Meal

    /// Remove one specific meal plan entry and undo its grocery contributions.
    func removeMeal(_ planID: UUID, groceryService: GroceryService) async -> Bool {
        Logger.supabase.info("removeMeal: planID=\(planID.uuidString)")

        // 1. Undo grocery contributions for this specific meal
        _ = await groceryService.removeContributions(forMealPlan: planID)

        // 2. Delete the meal plan row
        do {
            try await supabase
                .from("meal_plans")
                .delete()
                .eq("id", value: planID.uuidString)
                .execute()

            Logger.supabase.info("removeMeal: deleted")
            return true
        } catch {
            Logger.supabase.error("removeMeal: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Scheduling Check

    /// Returns true if the recipe is currently assigned to any meal plan
    /// in this household. Used to block deletion of in-use recipes.
    /// Fails closed (returns true) on error to prevent unsafe deletion.
    func isRecipeScheduled(_ recipeID: UUID) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return false }

        do {
            let rows: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .eq("recipe_id", value: recipeID.uuidString)
                .limit(1)
                .execute()
                .value

            return !rows.isEmpty
        } catch {
            Logger.supabase.error("isRecipeScheduled: check failed — \(error.localizedDescription)")
            // Fail closed: assume scheduled to prevent unsafe deletion
            return true
        }
    }

    // MARK: - Clear Day

    /// Remove all meals for (household, date) and undo their grocery
    /// contributions. Order matters: delete first, then only undo
    /// contributions for the rows the server actually removed. That
    /// way an RLS-silent failure can't strip groceries from meals that
    /// are still in the plan.
    func clearDayWithGroceries(on date: Date, groceryService: GroceryService) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return false }

        let iso = Self.isoDate(from: date)

        // 1. Snapshot current rows for logging context.
        let beforeRows = await fetchSlotRows(householdID: householdID, iso: iso)
        Logger.supabase.info("clearDayWithGroceries: date=\(iso) — \(beforeRows.count) row(s) before delete")

        guard !beforeRows.isEmpty else { return true }

        // 2. Delete with .select() so we get back the rows the server
        //    actually removed.
        let deletedIDs: [UUID]
        do {
            let deleted: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .delete()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
                .select()
                .execute()
                .value
            deletedIDs = deleted.map(\.id)
            Logger.supabase.info("clearDayWithGroceries: server reported \(deletedIDs.count) row(s) deleted")
        } catch {
            Logger.supabase.error("clearDayWithGroceries: delete failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }

        // 3. Verify the slot is empty.
        let afterRows = await fetchSlotRows(householdID: householdID, iso: iso)
        Logger.supabase.info("clearDayWithGroceries: date=\(iso) — \(afterRows.count) row(s) after delete")

        if !afterRows.isEmpty {
            let leftover = afterRows.map { $0.id.uuidString }.joined(separator: ", ")
            Logger.supabase.error("clearDayWithGroceries: \(afterRows.count) row(s) still present after delete (likely RLS blocked the DELETE). leftover=[\(leftover)]")
            errorMessage = "Couldn't remove this meal. Please try again or check your account permissions."
            return false
        }

        // 4. Now that the meal_plans rows are truly gone, undo their
        //    grocery contributions.
        for id in deletedIDs {
            _ = await groceryService.removeContributions(forMealPlan: id)
        }

        return true
    }

    /// Delete all meal plan rows for (household, date) directly in the
    /// database. Verifies the result by counting rows before and after
    /// and re-reading the slot. Does NOT mutate `plansByDate` — the
    /// caller is expected to refetch so the UI sees authoritative state.
    func clearSlot(on date: Date) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("clearSlot: no household ID")
            return false
        }

        let iso = Self.isoDate(from: date)

        // 1. Count rows currently in the slot.
        let beforeRows = await fetchSlotRows(householdID: householdID, iso: iso)
        Logger.supabase.info("clearSlot: date=\(iso) — \(beforeRows.count) row(s) before delete")

        if beforeRows.isEmpty {
            // Nothing to do, but surface the no-op clearly in logs.
            Logger.supabase.info("clearSlot: date=\(iso) — slot already empty")
            return true
        }

        // 2. Issue the delete and capture which rows the server reports
        //    as deleted. This catches the silent-no-op case (e.g. an
        //    RLS policy that grants SELECT but not DELETE) — without
        //    .select() the API call would succeed even when zero rows
        //    were actually removed.
        let deletedIDs: [UUID]
        do {
            let deleted: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .delete()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
                .select()
                .execute()
                .value

            deletedIDs = deleted.map(\.id)
            Logger.supabase.info("clearSlot: server reported \(deletedIDs.count) row(s) deleted")
        } catch {
            Logger.supabase.error("clearSlot: delete failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }

        // 3. Re-read the slot to confirm it is actually empty.
        let afterRows = await fetchSlotRows(householdID: householdID, iso: iso)
        Logger.supabase.info("clearSlot: date=\(iso) — \(afterRows.count) row(s) after delete")

        if !afterRows.isEmpty {
            let leftover = afterRows.map { $0.id.uuidString }.joined(separator: ", ")
            Logger.supabase.error("clearSlot: \(afterRows.count) row(s) still present after delete (likely RLS blocked the DELETE). leftover=[\(leftover)]")
            errorMessage = "Couldn't remove this meal. Please try again or check your account permissions."
            return false
        }

        if deletedIDs.count != beforeRows.count {
            Logger.supabase.warning("clearSlot: deleted \(deletedIDs.count) of \(beforeRows.count) row(s) — slot is empty but counts disagree")
        }

        return true
    }

    /// Read all current meal_plans rows for a single (household, date)
    /// directly from the DB. Used by clearSlot for before/after
    /// verification — bypasses any local cache.
    private func fetchSlotRows(householdID: UUID, iso: String) async -> [MealPlanRow] {
        do {
            return try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
                .execute()
                .value
        } catch {
            Logger.supabase.error("fetchSlotRows: failed — \(error.localizedDescription)")
            return []
        }
    }
}
