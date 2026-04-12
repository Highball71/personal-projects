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
    func fetchItems() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else {
            Logger.supabase.warning("fetchItems: no household ID set, returning empty list")
            items = []
            return
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
        } catch {
            Logger.supabase.error("fetchItems: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            isLoading = false
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

    /// Add grocery items with simple dedup.
    ///
    /// Dedup rules (Phase 2 — minimal):
    ///   1. Within the incoming batch, combine rows with the same
    ///      (trimmed/lowercased name, trimmed/lowercased unit).
    ///   2. For each unique batch item, look up an *unchecked* row in
    ///      the DB with the same (name, unit). If found, UPDATE its
    ///      quantity by adding the new amount. Otherwise, INSERT new.
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
        let mergedBatch = mergeBatch(inserts)
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

            // Map unchecked items by dedup key. If legacy duplicates exist,
            // keep the first one encountered.
            var uncheckedByKey: [String: SupabaseGroceryItem] = [:]
            for item in current where !item.isChecked {
                let key = Self.dedupeKey(name: item.name, unit: item.unit)
                if uncheckedByKey[key] == nil {
                    uncheckedByKey[key] = item
                }
            }

            // Step 3: split each batch item into update or insert. Also
            // remember the (groceryItemID, contributed quantity) pairs so
            // we can record contributions after.
            var toInsert: [GroceryItemInsert] = []
            /// (grocery_item.id, contributed_quantity) — used to build
            /// contribution rows AFTER grocery items exist.
            var contributions: [(groceryItemID: UUID, quantity: Double)] = []
            var toUpdate: [(id: UUID, newQuantity: Double)] = []

            for item in mergedBatch {
                let key = Self.dedupeKey(name: item.name, unit: item.unit)
                if let existing = uncheckedByKey[key] {
                    let newQty = existing.quantity + item.quantity
                    toUpdate.append((id: existing.id, newQuantity: newQty))
                    contributions.append((groceryItemID: existing.id, quantity: item.quantity))
                    Logger.supabase.info("addItems: merge \"\(item.name)\" \(existing.quantity) + \(item.quantity) = \(newQty) [\(item.unit)]")
                } else {
                    toInsert.append(item)
                    Logger.supabase.info("addItems: new \"\(item.name)\" \(item.quantity) \(item.unit)")
                }
            }

            // Step 4: apply updates (one request per merged item)
            for update in toUpdate {
                try await supabase
                    .from("grocery_items")
                    .update(["quantity": update.newQuantity])
                    .eq("id", value: update.id.uuidString)
                    .execute()
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

    /// Undo a meal plan's contributions to the grocery list.
    /// For each contribution row linking to this meal plan:
    ///   - Subtract the contribution's quantity from the grocery item.
    ///   - If the result is effectively zero, delete the grocery item
    ///     entirely (which cascades the contribution).
    ///   - Otherwise, update the grocery item's quantity and delete
    ///     the contribution row.
    ///
    /// Safe to call on a meal plan that has no contributions (no-op).
    /// Does not touch items added via the manual path (no contributions).
    func removeContributions(forMealPlan mealPlanID: UUID) async -> Bool {
        Logger.supabase.info("removeContributions: meal plan \(mealPlanID.uuidString)")

        do {
            // Fetch contributions for this meal plan.
            let contributions: [GroceryContributionRow] = try await supabase
                .from("grocery_contributions")
                .select()
                .eq("meal_plan_id", value: mealPlanID.uuidString)
                .execute()
                .value

            Logger.supabase.info("removeContributions: found \(contributions.count) contribution(s)")
            guard !contributions.isEmpty else { return true }

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
                    Logger.supabase.info("removeContributions: grocery item already gone, cleaned up contribution")
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
                    Logger.supabase.info("removeContributions: deleted \"\(item.name)\" (would be \(newQty))")
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

                    Logger.supabase.info("removeContributions: reduced \"\(item.name)\" by \(contrib.quantity) → \(newQty)")
                }
            }

            await fetchItems()
            return true
        } catch {
            Logger.supabase.error("removeContributions: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Dedup helpers

    /// Combine incoming items that share a dedup key. Preserves the
    /// first spelling and unit encountered.
    private func mergeBatch(_ inserts: [GroceryItemInsert]) -> [GroceryItemInsert] {
        var mergedByKey: [String: GroceryItemInsert] = [:]
        var orderedKeys: [String] = []

        for item in inserts {
            let key = Self.dedupeKey(name: item.name, unit: item.unit)
            if let existing = mergedByKey[key] {
                mergedByKey[key] = GroceryItemInsert(
                    householdID: existing.householdID,
                    name: existing.name,
                    quantity: existing.quantity + item.quantity,
                    unit: existing.unit
                )
            } else {
                mergedByKey[key] = item
                orderedKeys.append(key)
            }
        }

        return orderedKeys.compactMap { mergedByKey[$0] }
    }

    /// Key used to decide whether two items represent the same thing.
    /// Trimmed + lowercased on both name and unit. Exact match only —
    /// no synonym handling, no unit conversion.
    private static func dedupeKey(name: String, unit: String) -> String {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(cleanName)|\(cleanUnit)"
    }

    // MARK: - Update

    /// Flip the is_checked flag for a single item.
    func toggleChecked(_ item: SupabaseGroceryItem) async {
        do {
            try await supabase
                .from("grocery_items")
                .update(["is_checked": !item.isChecked])
                .eq("id", value: item.id.uuidString)
                .execute()

            Logger.supabase.info("toggleChecked: item id=\(item.id.uuidString) now=\(!item.isChecked)")
            await fetchItems()
        } catch {
            Logger.supabase.error("toggleChecked: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deleteItem(_ id: UUID) async {
        do {
            try await supabase
                .from("grocery_items")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()

            items.removeAll { $0.id == id }
            Logger.supabase.info("deleteItem: deleted id=\(id.uuidString)")
        } catch {
            Logger.supabase.error("deleteItem: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }

    /// Delete all checked items (useful for "clear completed").
    func clearChecked() async {
        guard let householdID = SupabaseManager.shared.currentHouseholdID else { return }

        do {
            try await supabase
                .from("grocery_items")
                .delete()
                .eq("household_id", value: householdID.uuidString)
                .eq("is_checked", value: true)
                .execute()

            Logger.supabase.info("clearChecked: cleared checked items")
            await fetchItems()
        } catch {
            Logger.supabase.error("clearChecked: failed — \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
