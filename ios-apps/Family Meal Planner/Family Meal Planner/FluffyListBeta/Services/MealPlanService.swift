//
//  MealPlanService.swift
//  FluffyList
//
//  CRUD for meal_plans via Supabase.
//  Household-scoped via RLS.
//
//  Slot rule (per-person meals, Phase 3): the slot key is
//  (household, date, member_id). member_id NULL is the household slot
//  — the whole-family meal, today's only kind before Phase 3 — and
//  each member gets at most one slot per day, so a day can hold one
//  household meal plus up to one meal per member. The DB still
//  permits multiple rows per slot — the rule is enforced in the app
//  by the assign path, which clears exactly its own slot before
//  inserting. Legacy multi-row slots are tolerated on read and
//  collapsed on the next assign or remove.
//

import Combine
import Foundation
import os
import Supabase

/// Summary of a copy-last-week run — per-day tally for the caller's
/// toast. Produced by `MealPlanService.copyPreviousWeek`.
struct CopyWeekResult: Equatable {
    var copied = 0
    /// Target days that already held a meal — kept, never overwritten.
    var skippedFilled = 0
    /// Target days already in the past — skipped silently.
    var skippedPast = 0
    /// Source rows whose recipe couldn't be found locally.
    var skippedNoRecipe = 0
    /// Copies that reached the write path but failed.
    var failed = 0
    /// True when the previous week had no meals to copy at all.
    var sourceEmpty = false
}

/// Which meal_plans rows on a date an operation targets.
/// The slot key is (date, member_id): NULL member_id is the household
/// slot, each member id is that person's slot, and `.wholeDay` is
/// every slot at once (the day-level "Remove" action).
enum MealSlotScope: Equatable {
    case wholeDay
    case household
    case member(UUID)

    /// The scope that owns a meal assigned to `memberID`
    /// (nil = the household slot).
    static func slot(for memberID: UUID?) -> MealSlotScope {
        memberID.map { .member($0) } ?? .household
    }
}

@MainActor
final class MealPlanService: ObservableObject {
    /// Plans for the currently-loaded week, keyed by ISO date string.
    /// Each date maps to an array of meal plan rows (multi-meal per day).
    @Published var plansByDate: [String: [MealPlanRow]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    /// Monotonic counter for fetchPlans calls. With week navigation a
    /// user can request week B while week A's fetch is still in
    /// flight; when A finally lands it must not overwrite B's rows
    /// (or flip isLoading/errorMessage under B). MainActor-confined,
    /// so bumping and comparing it is race-free.
    private var fetchGeneration = 0

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
    /// Returns false when the load failed (so the UI can show an error
    /// instead of an empty week); discardable for legacy call sites.
    ///
    /// `quiet` reconciles without announcing: isLoading is never
    /// touched, so no loading UI appears — used after an optimistic
    /// local edit, where the screen already shows the expected result
    /// and the fetch only confirms it (or picks up another household
    /// member's concurrent changes).
    @discardableResult
    func fetchPlans(weekStart: Date, quiet: Bool = false) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("fetchPlans: no household ID set")
            plansByDate = [:]
            return true
        }

        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let startISO = Self.isoDate(from: weekStart)
        let endISO = Self.isoDate(from: weekEnd)

        Logger.supabase.info("fetchPlans: loading week \(startISO)..<\(endISO) for household \(householdID.uuidString)\(quiet ? " (quiet)" : "")")
        if !quiet { isLoading = true }
        fetchGeneration += 1
        let generation = fetchGeneration

        do {
            let rows: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .gte("date", value: startISO)
                .lt("date", value: endISO)
                .execute()
                .value

            // A newer fetch started while this one was in flight —
            // its week is the one on screen; drop this result whole.
            guard generation == fetchGeneration else { return true }

            var map: [String: [MealPlanRow]] = [:]
            for row in rows {
                map[row.date, default: []].append(row)
            }
            plansByDate = map

            Logger.supabase.info("fetchPlans: loaded \(rows.count) plan(s)")
            if !quiet { isLoading = false }
            return true
        } catch {
            guard generation == fetchGeneration else { return true }
            Logger.supabase.error("fetchPlans: failed — \(error.localizedDescription)")
            // A quiet reconcile failing is not an event: the local
            // state already shows the confirmed result, so no
            // errorMessage either — the next loud fetch will report.
            if !quiet {
                errorMessage = error.localizedDescription
                isLoading = false
            }
            return false
        }
    }

    // MARK: - Add Meal

    /// Insert a new meal plan row for (household, date, member).
    /// memberID nil = a household meal. Multiple rows per date are
    /// allowed (one per slot).
    func addMeal(recipeID: UUID, on date: Date, memberID: UUID? = nil) async -> UUID? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("addMeal: no household ID")
            errorMessage = "No household selected."
            return nil
        }

        let iso = Self.isoDate(from: date)
        Logger.supabase.info("addMeal: recipe=\(recipeID.uuidString) date=\(iso) member=\(memberID?.uuidString ?? "household")")

        let insert = MealPlanInsert(
            householdID: householdID,
            recipeID: recipeID,
            memberID: memberID,
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

    /// Assign a recipe to a slot (household, date, member), enforcing
    /// the one-meal-per-slot rule:
    ///   1. Clear THIS slot only — delete any existing meal_plans rows
    ///      for (date, member) and undo their grocery contributions.
    ///      A household assign never touches member meals, and a
    ///      member assign never touches the household meal or other
    ///      members' meals.
    ///   2. Insert the new meal plan row
    ///   3. Fetch the recipe's ingredients
    ///   4. Insert them as grocery items with contribution tracking
    ///      (member meals contribute groceries identically — decided
    ///      2026-08-27)
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
        memberID: UUID? = nil,
        recipeService: RecipeService,
        groceryService: GroceryService
    ) async -> UUID? {
        // Guard: don't allow assigning meals to past dates.
        if Calendar.current.startOfDay(for: date) < Calendar.current.startOfDay(for: Date()) {
            Logger.supabase.warning("addMealWithGroceries: blocked — date \(Self.isoDate(from: date)) is in the past")
            errorMessage = "You can only plan meals for today or future days."
            return nil
        }

        // 1. Clear this slot first so (date, member) holds at most one
        //    meal after we insert. Safe on an already-empty slot, and
        //    scoped: the rest of the day's meals are untouched.
        //
        //    CRITICAL: if the clear fails (silent RLS rejection, network
        //    error, etc.) we MUST NOT proceed with the insert. Doing so
        //    would leave the slot stacked (old + new) and double the
        //    grocery contributions. errorMessage is already set by
        //    clearMealsWithGroceries on failure.
        let cleared = await clearMealsWithGroceries(
            on: date,
            scope: .slot(for: memberID),
            groceryService: groceryService
        )
        guard cleared else {
            Logger.supabase.error("addMealWithGroceries: aborting insert — slot clear failed for date=\(Self.isoDate(from: date))")
            return nil
        }

        // 2. Insert meal plan row
        guard let newPlanID = await addMeal(recipeID: recipe.id, on: date, memberID: memberID) else {
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

    // MARK: - Local (optimistic) week-map edits

    /// The optimistic half of swipe-to-remove: take one plan row out
    /// of the local week map WITHOUT any server call, so the row can
    /// leave the screen immediately instead of waiting on the round
    /// trip. Returns the date's previous rows so a failed delete can
    /// restore them exactly. Purely local — the server delete (and its
    /// grocery unwind) still goes through removeMeal.
    func removeLocalPlan(_ planID: UUID, dateISO: String) -> [MealPlanRow]? {
        invalidateInFlightFetches()
        let snapshot = plansByDate[dateISO]
        let remaining = (snapshot ?? []).filter { $0.id != planID }
        plansByDate[dateISO] = remaining.isEmpty ? nil : remaining
        return snapshot
    }

    /// Optimistically clear a whole date locally — the "Clear the
    /// Whole Day" counterpart of removeLocalPlan. Same contract:
    /// returns the previous rows for restore on failure.
    func removeLocalDay(dateISO: String) -> [MealPlanRow]? {
        invalidateInFlightFetches()
        let snapshot = plansByDate[dateISO]
        plansByDate[dateISO] = nil
        return snapshot
    }

    /// Optimistically replace one slot's rows with a single new row —
    /// the local half of Replace. Removes any rows for (date, member)
    /// and appends the new one, mirroring what addMealWithGroceries
    /// just did on the server.
    func replaceLocalSlot(with row: MealPlanRow) {
        invalidateInFlightFetches()
        var rows = (plansByDate[row.date] ?? [])
            .filter { $0.memberID != row.memberID }
        rows.append(row)
        plansByDate[row.date] = rows
    }

    /// Put back the rows captured before an optimistic removal whose
    /// server delete then failed.
    func restoreLocalPlans(_ rows: [MealPlanRow]?, dateISO: String) {
        invalidateInFlightFetches()
        plansByDate[dateISO] = rows
    }

    /// A local edit makes any fetch already in flight stale — its rows
    /// predate the edit, so letting it land would resurrect a removed
    /// row (or erase an optimistic replace) for a beat. Bumping the
    /// generation makes such a fetch drop its result; the quiet
    /// reconcile that follows every optimistic edit re-reads truth on
    /// a fresh generation.
    private func invalidateInFlightFetches() {
        fetchGeneration += 1
        // A superseded fetch skips its own isLoading = false (it must
        // not stomp newer state), and no newer fetch exists yet to
        // clear it — so clear it here or it could stick true forever.
        isLoading = false
    }

    // MARK: - Remove Single Meal

    /// Remove one specific meal plan entry and undo its grocery contributions.
    ///
    /// Order matters (same shape as clearMealsWithGroceries):
    ///   1. SNAPSHOT the contributions — the DB cascade destroys them
    ///      the instant the meal_plans row is deleted.
    ///   2. Delete WITH .select() verification. Without it, an
    ///      RLS-blocked delete affects zero rows yet returns success —
    ///      the UI would report the meal removed while the server
    ///      still has it (and the old code had already stripped its
    ///      groceries by then). Zero deleted rows is a surfaced error.
    ///   3. Only then settle groceries, from the snapshot.
    func removeMeal(_ planID: UUID, groceryService: GroceryService) async -> Bool {
        Logger.supabase.info("removeMeal: planID=\(planID.uuidString)")

        // 1. Snapshot contributions while the meal plan still exists.
        guard let snapshot = await groceryService.fetchContributions(forMealPlans: [planID]) else {
            errorMessage = "Couldn't remove that meal. Please try again."
            return false
        }

        // 2. Delete the meal plan row, verified.
        do {
            let deleted: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .delete()
                .eq("id", value: planID.uuidString)
                .select()
                .execute()
                .value

            guard !deleted.isEmpty else {
                Logger.supabase.error("removeMeal: server deleted 0 rows for planID=\(planID.uuidString) (RLS blocked, or already gone)")
                errorMessage = "Couldn't remove that meal from the plan."
                return false
            }
            Logger.supabase.info("removeMeal: deleted")
        } catch {
            Logger.supabase.error("removeMeal: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }

        // 3. Settle groceries for the confirmed-deleted meal.
        _ = await groceryService.settleContributions(snapshot)
        return true
    }

    // MARK: - Scheduling Check

    /// Returns true if the recipe is assigned to any LIVE meal plan
    /// entry — dated today or later — in this household. Used to block
    /// deletion of in-use recipes.
    ///
    /// Past entries deliberately do NOT block: past days are read-only
    /// in the week view, so the user has no way to remove them — a
    /// guard counting them locks the recipe forever (the build-119
    /// Shepherd's Pie bug). The schema has no archived/soft-delete
    /// state; date < today is the only "past" a meal plan entry has.
    /// Deleting a recipe leaves past entries as recipe-less history
    /// rows (meal_plans.recipe_id is ON DELETE SET NULL).
    ///
    /// Fails closed (returns true) on error to prevent unsafe deletion.
    /// `today` is injectable for tests.
    func isRecipeScheduled(_ recipeID: UUID, asOf today: Date = Date()) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return false }

        do {
            let rows: [MealPlanRow] = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .eq("recipe_id", value: recipeID.uuidString)
                .gte("date", value: Self.isoDate(from: today))
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

    /// Remove every live (today-or-later) meal plan entry for a recipe,
    /// settling each meal's grocery contributions — the "Remove from
    /// meal plan and delete" path, so the user isn't bounced to the
    /// week view to hunt entries down before a delete can go through.
    /// Past entries are left alone (they don't block deletion).
    func removeScheduledMeals(
        for recipeID: UUID,
        groceryService: GroceryService,
        asOf today: Date = Date()
    ) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return false }

        let rows: [MealPlanRow]
        do {
            rows = try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .eq("recipe_id", value: recipeID.uuidString)
                .gte("date", value: Self.isoDate(from: today))
                .execute()
                .value
        } catch {
            Logger.supabase.error("removeScheduledMeals: fetch failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }

        Logger.supabase.info("removeScheduledMeals: removing \(rows.count) live entr\(rows.count == 1 ? "y" : "ies") for recipe \(recipeID.uuidString)")
        for row in rows {
            guard await removeMeal(row.id, groceryService: groceryService) else {
                // removeMeal already set errorMessage.
                return false
            }
        }
        return true
    }

    // MARK: - Clear Day / Slot

    /// Remove ALL meals for (household, date) — every slot, household
    /// and member alike — and undo their grocery contributions. The
    /// day-level "nuke the day" action. The snapshot-before-delete
    /// unwind settles contributions for every removed meal, however
    /// many the day held.
    func clearDayWithGroceries(on date: Date, groceryService: GroceryService) async -> Bool {
        await clearMealsWithGroceries(on: date, scope: .wholeDay, groceryService: groceryService)
    }

    /// Member-scoped variant: remove only one slot's meals —
    /// the household slot (memberID nil) or one member's slot —
    /// leaving the rest of the day untouched.
    func clearSlotWithGroceries(
        on date: Date,
        memberID: UUID?,
        groceryService: GroceryService
    ) async -> Bool {
        await clearMealsWithGroceries(on: date, scope: .slot(for: memberID), groceryService: groceryService)
    }

    /// Shared core for day- and slot-scoped removal: delete the
    /// scope's meal_plans rows and undo their grocery contributions.
    ///
    /// Ordering is subtle because two constraints pull in opposite
    /// directions:
    ///   - RLS safety: only settle groceries for rows the server
    ///     actually deleted, so a silent RLS failure can't strip
    ///     groceries from meals still in the plan.
    ///   - The DB cascade: grocery_contributions.meal_plan_id is
    ///     ON DELETE CASCADE (migration 005), so the contribution rows
    ///     vanish the instant the meal_plans rows are deleted —
    ///     querying them after the delete finds nothing.
    /// Resolution: SNAPSHOT the contribution rows first, then delete
    /// and verify, then settle grocery quantities from the snapshot,
    /// filtered to the rows the server confirmed deleted.
    private func clearMealsWithGroceries(
        on date: Date,
        scope: MealSlotScope,
        groceryService: GroceryService
    ) async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return false }

        let iso = Self.isoDate(from: date)

        // 1. Snapshot current rows for logging context.
        let beforeRows = await fetchSlotRows(householdID: householdID, iso: iso, scope: scope)
        Logger.supabase.info("clearMealsWithGroceries: date=\(iso) scope=\(String(describing: scope)) — \(beforeRows.count) row(s) before delete")

        guard !beforeRows.isEmpty else { return true }

        // 2. Snapshot the grocery contributions BEFORE deleting the
        //    meal plans — after the delete the cascade has already
        //    destroyed them. If the snapshot fails, abort while the
        //    meals are still intact; deleting anyway would strand the
        //    grocery items with no way to ever settle them.
        guard let contributionSnapshot = await groceryService.fetchContributions(
            forMealPlans: beforeRows.map(\.id)
        ) else {
            Logger.supabase.error("clearMealsWithGroceries: aborting — couldn't snapshot grocery contributions")
            errorMessage = "Couldn't remove this meal. Please try again."
            return false
        }

        // 3. Delete with .select() so we get back the rows the server
        //    actually removed.
        let deletedIDs: [UUID]
        do {
            let query = supabase
                .from("meal_plans")
                .delete()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
            let deleted: [MealPlanRow] = try await Self.applyScope(scope, to: query)
                .select()
                .execute()
                .value
            deletedIDs = deleted.map(\.id)
            Logger.supabase.info("clearMealsWithGroceries: server reported \(deletedIDs.count) row(s) deleted")
        } catch {
            Logger.supabase.error("clearMealsWithGroceries: delete failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }

        // 4. Verify the scope is empty.
        let afterRows = await fetchSlotRows(householdID: householdID, iso: iso, scope: scope)
        Logger.supabase.info("clearMealsWithGroceries: date=\(iso) — \(afterRows.count) row(s) after delete")

        // 5. Settle grocery quantities from the snapshot — but only
        //    for meal plans the server confirmed deleted, preserving
        //    the RLS-safety rule even on a partial delete. The
        //    contribution rows themselves are already gone (cascade);
        //    the snapshot carries the amounts to subtract.
        let deletedSet = Set(deletedIDs)
        let toSettle = contributionSnapshot.filter { deletedSet.contains($0.mealPlanID) }
        _ = await groceryService.settleContributions(toSettle)

        if !afterRows.isEmpty {
            let leftover = afterRows.map { $0.id.uuidString }.joined(separator: ", ")
            Logger.supabase.error("clearMealsWithGroceries: \(afterRows.count) row(s) still present after delete (likely RLS blocked the DELETE). leftover=[\(leftover)]")
            errorMessage = "Couldn't remove this meal. Please try again or check your account permissions."
            return false
        }

        return true
    }

    /// Append the scope's member_id filter to a meal_plans query.
    /// `.wholeDay` adds nothing; `.household` matches member_id IS
    /// NULL (pre-013 rows and whole-family meals); `.member` matches
    /// one member's rows.
    private static func applyScope(
        _ scope: MealSlotScope,
        to query: PostgrestFilterBuilder
    ) -> PostgrestFilterBuilder {
        switch scope {
        case .wholeDay:
            return query
        case .household:
            return query.is("member_id", value: nil)
        case .member(let id):
            return query.eq("member_id", value: id.uuidString)
        }
    }

    // NOTE: a `clearSlot(on:)` helper used to live here. It deleted
    // meal_plans rows without ever touching grocery contributions —
    // any caller would strand grocery items exactly like the bug this
    // section fixes. It had no callers left, so it was removed rather
    // than fixed. Use clearDayWithGroceries instead.

    // MARK: - Copy Last Week

    /// A slot's identity within one week: date + owner. Used to
    /// collapse legacy multi-row slots and to skip filled targets
    /// per (day, member) — copying Maya's Tuesday meal is skipped only
    /// when the target Tuesday already has a meal FOR MAYA, not when
    /// it has a household meal or Sam's meal.
    static func slotKey(date: String, memberID: UUID?) -> String {
        "\(date)|\(memberID?.uuidString.lowercased() ?? "household")"
    }

    /// Copy the previous week's meals onto the week starting at
    /// `weekStart`, shifting each by +7 days.
    ///
    /// Rules (decided 2026-08-27, extended to per-person slots in
    /// Phase 3):
    ///   - Copies preserve each meal's assignment: a member meal is
    ///     copied for that same member; a household meal stays a
    ///     household meal.
    ///   - Target slots that already hold a meal for the SAME target
    ///     (household, or that member) are SKIPPED — existing plans
    ///     are never overwritten. Other slots on the same day still
    ///     copy.
    ///   - Target days already in the past are skipped silently. The
    ///     assign path refuses past dates with an error; we pre-filter
    ///     so a routine copy never surfaces one.
    ///   - Each copy goes through `addMealWithGroceries` — the single
    ///     write path — so grocery contributions carry over exactly as
    ///     if the meal had been assigned by hand. Because it is only
    ///     called on slots confirmed empty, its clear-first step is a
    ///     no-op and nothing existing is ever deleted.
    ///
    /// Reads both weeks fresh from the DB (never the local cache).
    /// Returns nil when a read fails (`errorMessage` is set); otherwise
    /// a `CopyWeekResult` tally. The caller should refetch the week.
    func copyPreviousWeek(
        weekStart: Date,
        recipeService: RecipeService,
        groceryService: GroceryService
    ) async -> CopyWeekResult? {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("copyPreviousWeek: no household ID")
            errorMessage = "No household selected."
            return nil
        }

        let cal = Calendar.current
        guard let prevStart = cal.date(byAdding: .day, value: -7, to: weekStart) else {
            return nil
        }

        // 1. Read both weeks straight from the DB.
        guard let sourceRows = await fetchWeekRows(householdID: householdID, weekStart: prevStart),
              let targetRows = await fetchWeekRows(householdID: householdID, weekStart: weekStart)
        else {
            errorMessage = "Couldn't read last week's plan. Please try again."
            return nil
        }

        // Slot rule: one meal per (day, member). Collapse legacy
        // multi-row slots to their first row (same convention as the
        // week view) and ignore orphan rows (recipe_id NULLed by a
        // recipe delete). Keyed per slot so a day's household meal and
        // member meals each survive the collapse.
        var sourceBySlot: [String: MealPlanRow] = [:]
        // Slot order within each date: preserve fetch order but keep it
        // deterministic — household copies before member meals.
        var slotOrderByDate: [String: [String]] = [:]
        for row in sourceRows where row.recipeID != nil {
            let key = Self.slotKey(date: row.date, memberID: row.memberID)
            if sourceBySlot[key] == nil {
                sourceBySlot[key] = row
                if row.memberID == nil {
                    slotOrderByDate[row.date, default: []].insert(key, at: 0)
                } else {
                    slotOrderByDate[row.date, default: []].append(key)
                }
            }
        }

        var result = CopyWeekResult()
        if sourceBySlot.isEmpty {
            result.sourceEmpty = true
            Logger.supabase.info("copyPreviousWeek: previous week is empty — nothing to copy")
            return result
        }

        let filledTargetSlots = Set(
            targetRows
                .filter { $0.recipeID != nil }
                .map { Self.slotKey(date: $0.date, memberID: $0.memberID) }
        )
        let today = cal.startOfDay(for: Date())

        // Recipes are needed for the addMealWithGroceries call below.
        if recipeService.recipes.isEmpty {
            _ = await recipeService.fetchRecipes()
        }

        // 2. Walk the seven day-offsets so all Date construction matches
        //    the week view's `weekDates` (no re-parsing of ISO strings,
        //    no UTC/local drift), then each day's slots.
        for offset in 0..<7 {
            guard let sourceDate = cal.date(byAdding: .day, value: offset, to: prevStart),
                  let targetDate = cal.date(byAdding: .day, value: offset, to: weekStart)
            else { continue }

            let sourceSlotKeys = slotOrderByDate[Self.isoDate(from: sourceDate)] ?? []
            guard !sourceSlotKeys.isEmpty else { continue } // nothing planned that day last week

            let targetISO = Self.isoDate(from: targetDate)
            let dayIsPast = cal.startOfDay(for: targetDate) < today

            for slotKey in sourceSlotKeys {
                guard let sourceRow = sourceBySlot[slotKey],
                      let recipeID = sourceRow.recipeID
                else { continue }

                if dayIsPast {
                    result.skippedPast += 1
                    Logger.supabase.info("copyPreviousWeek: skip \(targetISO) — in the past")
                    continue
                }
                let targetSlotKey = Self.slotKey(date: targetISO, memberID: sourceRow.memberID)
                if filledTargetSlots.contains(targetSlotKey) {
                    result.skippedFilled += 1
                    Logger.supabase.info("copyPreviousWeek: skip \(targetSlotKey) — already planned")
                    continue
                }
                guard let recipe = recipeService.recipes.first(where: { $0.id == recipeID }) else {
                    result.skippedNoRecipe += 1
                    Logger.supabase.warning("copyPreviousWeek: skip \(targetISO) — recipe \(recipeID.uuidString) not found locally")
                    continue
                }

                let newID = await addMealWithGroceries(
                    recipe: recipe,
                    on: targetDate,
                    memberID: sourceRow.memberID,
                    recipeService: recipeService,
                    groceryService: groceryService
                )
                if newID != nil {
                    result.copied += 1
                } else {
                    result.failed += 1
                }
            }
        }

        Logger.supabase.info("copyPreviousWeek: copied=\(result.copied) skippedFilled=\(result.skippedFilled) skippedPast=\(result.skippedPast) skippedNoRecipe=\(result.skippedNoRecipe) failed=\(result.failed)")
        return result
    }

    /// Read all meal_plans rows for the 7 days starting at `weekStart`,
    /// straight from the DB — no cache, and unlike `fetchPlans` this
    /// never mutates `plansByDate`. Returns nil on error.
    private func fetchWeekRows(householdID: UUID, weekStart: Date) async -> [MealPlanRow]? {
        guard let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else {
            return nil
        }
        do {
            return try await supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .gte("date", value: Self.isoDate(from: weekStart))
                .lt("date", value: Self.isoDate(from: weekEnd))
                .execute()
                .value
        } catch {
            Logger.supabase.error("fetchWeekRows: failed — \(error.localizedDescription)")
            return nil
        }
    }

    /// Read the current meal_plans rows for (household, date) within a
    /// scope, directly from the DB. Used by clearMealsWithGroceries
    /// for before/after verification — bypasses any local cache.
    private func fetchSlotRows(
        householdID: UUID,
        iso: String,
        scope: MealSlotScope = .wholeDay
    ) async -> [MealPlanRow] {
        do {
            let query = supabase
                .from("meal_plans")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .eq("date", value: iso)
            return try await Self.applyScope(scope, to: query)
                .execute()
                .value
        } catch {
            Logger.supabase.error("fetchSlotRows: failed — \(error.localizedDescription)")
            return []
        }
    }
}
