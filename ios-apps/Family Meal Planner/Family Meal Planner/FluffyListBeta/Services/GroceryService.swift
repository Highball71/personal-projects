//
//  GroceryService.swift
//  FluffyList
//
//  CRUD for grocery items via Supabase.
//  Household-scoped via RLS. Flat list — no week scoping, no dedup,
//  no quantity merging. Phase 1 simplicity.
//

import Combine
import Foundation
import os
import Supabase

@MainActor
final class GroceryService: ObservableObject {
    @Published var items: [SupabaseGroceryItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var supabase: SupabaseClient { SupabaseManager.shared.client }

    // MARK: - Fetch

    /// Load all grocery items for the current household.
    /// Returns false when the load failed (so the UI can show an error
    /// instead of "Nothing to buy yet"); discardable for legacy call sites.
    @discardableResult
    func fetchItems() async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("fetchItems: no household ID set, returning empty list")
            items = []
            return true
        }

        Logger.supabase.info("fetchItems: loading for household \(householdID.uuidString)")
        isLoading = true

        do {
            items = try await supabase
                .from("grocery_items")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .order("is_checked", ascending: true)
                .order("created_at", ascending: true)
                .execute()
                .value

            Logger.supabase.info("fetchItems: loaded \(self.items.count) item(s)")
            isLoading = false
            return true
        } catch {
            Logger.supabase.error("fetchItems: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Create

    /// Add grocery items (manual path — no meal plan linkage).
    /// Items added this way have no contribution rows, so clearing a
    /// meal plan can never remove them.
    func addItems(_ inserts: [GroceryItemInsert]) async -> Bool {
        await addItemsInternal(inserts, mealPlanID: nil)
    }

    /// Add grocery items and record them as contributions from a
    /// specific meal plan. Each resulting grocery_item gets a
    /// grocery_contributions row, so the contribution can be subtracted
    /// when the meal plan is cleared or replaced.
    func addItemsForMealPlan(mealPlanID: UUID, items: [GroceryItemInsert]) async -> Bool {
        await addItemsInternal(items, mealPlanID: mealPlanID)
    }

    /// Add grocery items with pantry-item dedup (rules in GroceryMerge).
    ///
    /// Dedup rules:
    ///   1. Within the incoming batch, combine rows whose NORMALIZED
    ///      names match (case/whitespace folded + explicit alias
    ///      table). Unit is NOT part of the key — "2 tbsp olive oil"
    ///      and "1/4 cup olive oil" are the same pantry item.
    ///   2. For each unique batch item, look up an *unchecked* DB row
    ///      with the same normalized name. If found, convert the
    ///      incoming amount into the ROW's unit (unit families in
    ///      GroceryMerge) and UPDATE the summed quantity; when the
    ///      units are incompatible, append the incoming amount to the
    ///      row's note instead ("1 piece + 2 tbsp") — one row either
    ///      way. Otherwise, INSERT new.
    ///   3. Checked items are treated as "already bought" and never
    ///      merged into — a new purchase creates a fresh unchecked row.
    ///
    /// If `mealPlanID` is non-nil, each resulting grocery_item gets a
    /// grocery_contributions row linking it to that meal plan with the
    /// quantity contributed by this batch.
    private func addItemsInternal(
        _ inserts: [GroceryItemInsert],
        mealPlanID: UUID?
    ) async -> Bool {
        guard !inserts.isEmpty else { return true }
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.error("addItems: no household ID — cannot save")
            errorMessage = "No household selected."
            return false
        }

        // Step 1: merge duplicates within the incoming batch.
        // Note the per-key quantities so we can record contributions
        // that reflect what THIS batch contributed (not the merged
        // quantity across the whole grocery list).
        let mergedBatch = GroceryMerge.mergeInserts(inserts)
        Logger.supabase.info("addItems: batch dedup \(inserts.count) → \(mergedBatch.count) (mealPlan=\(mealPlanID?.uuidString ?? "nil"))")

        isLoading = true
        errorMessage = nil

        do {
            // Step 2: fetch current items (fresh) so we can match against
            // existing unchecked rows
            let current: [SupabaseGroceryItem] = try await supabase
                .from("grocery_items")
                .select()
                .eq("household_id", value: householdID.uuidString)
                .execute()
                .value

            // Map unchecked items by normalized pantry name. If legacy
            // duplicates exist, keep the first one encountered.
            var uncheckedByKey: [String: SupabaseGroceryItem] = [:]
            for item in current where !item.isChecked {
                let key = GroceryMerge.normalizeName(item.name)
                if uncheckedByKey[key] == nil {
                    uncheckedByKey[key] = item
                }
            }

            // Step 3: split each batch item into update or insert. Also
            // remember the (groceryItemID, contributed quantity) pairs so
            // we can record contributions after. Contributions are in
            // the ROW's unit (the incoming amount is converted first),
            // so settleContributions subtracts consistent numbers.
            var toInsert: [GroceryItemInsert] = []
            /// (grocery_item.id, contributed_quantity) — used to build
            /// contribution rows AFTER grocery items exist.
            var contributions: [(groceryItemID: UUID, quantity: Double)] = []
            /// Exactly one of quantity/note is set per update: the
            /// numeric-merge path updates quantity only (identical to
            /// the pre-015 request, safe before the migration), the
            /// incompatible-unit path updates note only.
            var toUpdate: [(id: UUID, quantity: Double?, note: String?)] = []

            for item in mergedBatch {
                let key = GroceryMerge.normalizeName(item.name)
                guard let existing = uncheckedByKey[key] else {
                    toInsert.append(item)
                    Logger.supabase.info("addItems: new \"\(item.name)\" \(item.quantity) \(item.unit)")
                    continue
                }

                let incoming = GroceryMerge.Amount(quantity: item.quantity, unit: item.unit)
                if let converted = GroceryMerge.convertedForRow(existingUnit: existing.unit, incoming: incoming) {
                    let newQty = existing.quantity + converted
                    toUpdate.append((id: existing.id, quantity: newQty, note: nil))
                    contributions.append((groceryItemID: existing.id, quantity: converted))
                    Logger.supabase.info("addItems: merge \"\(item.name)\" \(existing.quantity) + \(converted) = \(newQty) [\(existing.unit)]")
                } else {
                    // Incompatible units: one row, both amounts. The
                    // extra amount lives in the note TEXT, not the row
                    // quantity, so its contribution is 0 — the unwind
                    // must never subtract what was never added
                    // numerically. (Removing that meal later leaves
                    // the note text behind; informational only.)
                    var newNote = GroceryMerge.appendedNote(existing.note, adding: GroceryMerge.amountText(incoming))
                    if let itemNote = item.note, !itemNote.isEmpty {
                        newNote = GroceryMerge.appendedNote(newNote, adding: itemNote)
                    }
                    toUpdate.append((id: existing.id, quantity: nil, note: newNote))
                    contributions.append((groceryItemID: existing.id, quantity: 0))
                    Logger.supabase.info("addItems: incompatible units for \"\(item.name)\" — noted \"\(newNote)\" on the \(existing.unit) row")
                }
            }

            // Step 4: apply updates (one request per merged item)
            for update in toUpdate {
                if let quantity = update.quantity {
                    try await supabase
                        .from("grocery_items")
                        .update(["quantity": quantity])
                        .eq("id", value: update.id.uuidString)
                        .execute()
                }
                if let note = update.note {
                    try await supabase
                        .from("grocery_items")
                        .update(["note": note])
                        .eq("id", value: update.id.uuidString)
                        .execute()
                }
            }

            // Step 5: bulk insert new items, capture returned rows so we
            // know their IDs for contribution linkage.
            if !toInsert.isEmpty {
                let insertedRows: [SupabaseGroceryItem] = try await supabase
                    .from("grocery_items")
                    .insert(toInsert)
                    .select()
                    .execute()
                    .value

                // Supabase preserves insert order in the returned rows.
                for (row, batchItem) in zip(insertedRows, toInsert) {
                    contributions.append((groceryItemID: row.id, quantity: batchItem.quantity))
                }
            }

            // Step 6: record contributions if a meal plan is linked.
            if let mealPlanID, !contributions.isEmpty {
                let contributionInserts = contributions.map { pair in
                    GroceryContributionInsert(
                        groceryItemID: pair.groceryItemID,
                        mealPlanID: mealPlanID,
                        quantity: pair.quantity
                    )
                }

                try await supabase
                    .from("grocery_contributions")
                    .insert(contributionInserts)
                    .execute()

                Logger.supabase.info("addItems: recorded \(contributionInserts.count) contribution(s) for meal plan \(mealPlanID.uuidString)")
            }

            Logger.supabase.info("addItems: done — \(toUpdate.count) merged, \(toInsert.count) inserted")
            await fetchItems()
            isLoading = false
            return true
        } catch {
            Logger.supabase.error("addItems: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }

    // MARK: - Remove contributions

    // (removeContributions(forMealPlan:) is gone: its only caller,
    // removeMeal, settled groceries BEFORE the delete — so an
    // RLS-blocked delete could silently keep the meal while the
    // groceries were already stripped. removeMeal now snapshots,
    // verifies the delete, then settles, like clearMealsWithGroceries.)

    /// Read the contribution rows for a set of meal plans.
    ///
    /// Used to SNAPSHOT contributions before a meal_plans delete: the
    /// DB cascade removes these rows the moment the meal plan goes,
    /// so this is the last chance to learn what each meal contributed
    /// to the grocery list. Returns nil on error — callers about to
    /// delete meal plans should abort rather than strand grocery
    /// items that can never be settled afterwards.
    func fetchContributions(forMealPlans mealPlanIDs: [UUID]) async -> [GroceryContributionRow]? {
        guard !mealPlanIDs.isEmpty else { return [] }

        do {
            let contributions: [GroceryContributionRow] = try await supabase
                .from("grocery_contributions")
                .select()
                .`in`("meal_plan_id", values: mealPlanIDs.map(\.uuidString))
                .execute()
                .value

            Logger.supabase.info("fetchContributions: found \(contributions.count) contribution(s) for \(mealPlanIDs.count) meal plan(s)")
            return contributions
        } catch {
            Logger.supabase.error("fetchContributions: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Settle grocery item quantities for the given contribution rows.
    /// For each contribution:
    ///   - Subtract the contribution's quantity from the grocery item.
    ///   - If the result is effectively zero, delete the grocery item
    ///     entirely (which cascades any remaining contribution row).
    ///   - Otherwise, update the grocery item's quantity and delete
    ///     the contribution row.
    ///
    /// Works from rows the caller already holds, so it settles
    /// correctly even when the contribution rows themselves no longer
    /// exist in the DB (cascaded away by a meal_plans delete) — the
    /// contribution-row deletes just match nothing in that case.
    ///
    /// Safe to call with an empty array (no-op).
    func settleContributions(_ contributions: [GroceryContributionRow]) async -> Bool {
        guard !contributions.isEmpty else { return true }

        do {
            for contrib in contributions {
                // Read the current grocery item quantity.
                let rows: [SupabaseGroceryItem] = try await supabase
                    .from("grocery_items")
                    .select()
                    .eq("id", value: contrib.groceryItemID.uuidString)
                    .execute()
                    .value

                guard let item = rows.first else {
                    // Grocery item already gone — just clean up the
                    // contribution row.
                    try await supabase
                        .from("grocery_contributions")
                        .delete()
                        .eq("id", value: contrib.id.uuidString)
                        .execute()
                    Logger.supabase.info("settleContributions: grocery item already gone, cleaned up contribution")
                    continue
                }

                let newQty = item.quantity - contrib.quantity

                // Epsilon check: if the result would be effectively zero
                // (or negative from any prior user edit), delete the item.
                if newQty <= 0.0001 {
                    try await supabase
                        .from("grocery_items")
                        .delete()
                        .eq("id", value: item.id.uuidString)
                        .execute()
                    Logger.supabase.info("settleContributions: deleted \"\(item.name)\" (would be \(newQty))")
                    // Cascade deletes the contribution row too.
                } else {
                    try await supabase
                        .from("grocery_items")
                        .update(["quantity": newQty])
                        .eq("id", value: item.id.uuidString)
                        .execute()

                    try await supabase
                        .from("grocery_contributions")
                        .delete()
                        .eq("id", value: contrib.id.uuidString)
                        .execute()

                    Logger.supabase.info("settleContributions: reduced \"\(item.name)\" by \(contrib.quantity) → \(newQty)")
                }
            }

            await fetchItems()
            return true
        } catch {
            Logger.supabase.error("settleContributions: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Update

    /// Flip the is_checked flag for a single item.
    @discardableResult
    func toggleChecked(_ item: SupabaseGroceryItem) async -> Bool {
        do {
            try await supabase
                .from("grocery_items")
                .update(["is_checked": !item.isChecked])
                .eq("id", value: item.id.uuidString)
                .execute()

            Logger.supabase.info("toggleChecked: item id=\(item.id.uuidString) now=\(!item.isChecked)")
            await fetchItems()
            return true
        } catch {
            Logger.supabase.error("toggleChecked: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Delete

    @discardableResult
    func deleteItem(_ id: UUID) async -> Bool {
        do {
            try await supabase
                .from("grocery_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            items.removeAll { $0.id == id }
            Logger.supabase.info("deleteItem: deleted id=\(id.uuidString)")
            return true
        } catch {
            Logger.supabase.error("deleteItem: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Delete all checked items (useful for "clear completed").
    @discardableResult
    func clearChecked() async -> Bool {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return true }

        do {
            try await supabase
                .from("grocery_items")
                .delete()
                .eq("household_id", value: householdID.uuidString)
                .eq("is_checked", value: true)
                .execute()

            Logger.supabase.info("clearChecked: cleared checked items")
            await fetchItems()
            return true
        } catch {
            Logger.supabase.error("clearChecked: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }
}
