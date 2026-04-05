//
//  MealPlanningStore.swift
//  FluffyList
//
//  Central service for meal plan mutations — assigning recipes to
//  meal slots, managing suggestions, and clearing slots.
//
//  Views call these methods instead of doing Core Data persistence
//  directly. Views still own their own @FetchRequest queries for
//  reactive display; this store owns all writes.
//

import CoreData
import Foundation

@MainActor @Observable
final class MealPlanningStore {

    /// Formatter used to build stable `yyyy-MM-dd` keys for dedup grouping.
    /// Using a string key avoids the floating-point rounding that
    /// `timeIntervalSince1970` introduces, which could cause two dates
    /// one microsecond apart to produce different keys and miss duplicates.
    private static let dedupeFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()

    private let persistence: PersistenceController

    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    /// Convenience initializer using the shared persistence controller.
    convenience init() {
        self.init(persistence: .shared)
    }

    // MARK: - Meal Assignment

    /// Assigns a recipe to today's dinner slot.
    /// Convenience wrapper around `assignRecipe(_:on:mealType:)`.
    func assignRecipeToTonight(_ recipe: CDRecipe) {
        assignRecipe(recipe, on: Date(), mealType: .dinner)
    }

    /// Assigns a recipe to a specific date and meal type.
    /// If the slot already has any plans (one or many duplicates), keeps one
    /// and deletes the rest, then updates that row's recipe. Invariant:
    /// after this call, exactly one CDMealPlan exists for (dayStart, mealType).
    func assignRecipe(_ recipe: CDRecipe, on date: Date, mealType: MealType) {
        let dayStart = DateHelper.stripTime(from: date)

        // TEMP DEBUG — remove before release
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        fmt.timeZone = TimeZone.current
        print("[TEMP DEBUG] assignRecipe — incoming date=\(fmt.string(from: date)) normalized=\(fmt.string(from: dayStart)) mealType=\(mealType.rawValue) recipe=\"\(recipe.name)\"")

        let existing = fetchMealPlans(for: dayStart, mealType: mealType)
        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] assignRecipe — found \(existing.count) existing plan(s) for this slot")
        if existing.count > 1 {
            print("[TEMP DEBUG] assignRecipe — DUPLICATES detected, collapsing to 1")
        }

        if let keeper = existing.first {
            // Keep one row, update it, delete any duplicates.
            keeper.date = dayStart
            keeper.recipe = recipe
            for dup in existing.dropFirst() {
                viewContext.delete(dup)
            }
        } else {
            let mealPlan = CDMealPlan(context: viewContext)
            mealPlan.id = UUID()
            mealPlan.date = dayStart
            mealPlan.mealTypeRaw = mealType.rawValue
            mealPlan.recipe = recipe
        }
        do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
    }

    /// Removes the recipe from a meal slot. Deletes ALL CDMealPlan rows
    /// for (date, mealType) — not just one — so duplicates from older
    /// builds get fully cleared in a single tap.
    func clearMealSlot(date: Date, mealType: MealType) {
        let dayStart = DateHelper.stripTime(from: date)
        let existing = fetchMealPlans(for: dayStart, mealType: mealType)
        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] clearMealSlot — deleting \(existing.count) plan(s) for \(mealType.rawValue) on \(dayStart)")
        for plan in existing {
            viewContext.delete(plan)
        }
        if !existing.isEmpty {
            do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
        }
    }

    // MARK: - Suggestions (Head Cook Flow)

    /// Creates a suggestion for the Head Cook to review. A given person can
    /// only have one pending suggestion per slot — re-suggesting replaces
    /// their earlier pick instead of stacking a new row.
    func createSuggestion(
        _ recipe: CDRecipe,
        on date: Date,
        mealType: MealType,
        suggestedBy: String
    ) {
        let dayStart = DateHelper.stripTime(from: date)

        // Remove this user's existing suggestion(s) for this slot so we
        // don't stack duplicates every time SuggestMealsView is applied.
        let request = CDMealSuggestion.fetchRequest()
        guard let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else { return }
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND mealTypeRaw == %@ AND suggestedBy ==[c] %@",
            dayStart as NSDate,
            nextDayStart as NSDate,
            mealType.rawValue,
            suggestedBy
        )
        if let prior = try? viewContext.fetch(request) {
            // TEMP DEBUG — remove before release
            print("[TEMP DEBUG] createSuggestion — removing \(prior.count) prior suggestion(s) from \"\(suggestedBy)\" for this slot")
            for s in prior { viewContext.delete(s) }
        }

        let suggestion = CDMealSuggestion(context: viewContext)
        suggestion.id = UUID()
        suggestion.date = dayStart
        suggestion.mealTypeRaw = mealType.rawValue
        suggestion.suggestedBy = suggestedBy
        suggestion.dateCreated = Date()
        suggestion.recipe = recipe
        do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
    }

    /// Head Cook approves a suggestion — promotes it to a real MealPlan entry
    /// and deletes the suggestion.
    func approveSuggestion(_ suggestion: CDMealSuggestion) {
        guard let recipe = suggestion.recipe else { return }
        assignRecipe(recipe, on: suggestion.date, mealType: suggestion.mealType)
        viewContext.delete(suggestion)
        do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
    }

    /// Head Cook rejects a suggestion — deletes it.
    func rejectSuggestion(_ suggestion: CDMealSuggestion) {
        viewContext.delete(suggestion)
        do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
    }

    // MARK: - Deduplication

    /// Heals existing data by collapsing duplicate CDMealPlan rows for the
    /// same (day, mealType) down to one. Call this once on app/session
    /// entry; it's a no-op when nothing is duplicated. Needed because
    /// earlier builds could create duplicates when sub-second Date drift
    /// defeated the exact-equality uniqueness check.
    func dedupeMealPlans() {
        let request = CDMealPlan.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMealPlan.date, ascending: true)]
        guard let all = try? viewContext.fetch(request) else { return }

        // Group by (stripped day, mealTypeRaw). Keep first, delete rest.
        var seen: [String: CDMealPlan] = [:]
        var duplicatesDeleted = 0
        for plan in all {
            // `date` is declared non-optional in Swift but the Core Data
            // model marks it optional — a CloudKit-synced row could have
            // nil. Read via KVC so we can safely default to distantPast.
            let rawDate = (plan.value(forKey: "date") as? Date) ?? Date.distantPast
            let dayStart = DateHelper.stripTime(from: rawDate)
            let key = "\(Self.dedupeFormatter.string(from: dayStart))|\(plan.mealTypeRaw)"
            if seen[key] != nil {
                viewContext.delete(plan)
                duplicatesDeleted += 1
            } else {
                // Normalize the keeper's date in case it had drifted.
                plan.date = dayStart
                seen[key] = plan
            }
        }
        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] dedupeMealPlans — scanned=\(all.count) unique=\(seen.count) duplicatesDeleted=\(duplicatesDeleted)")
        if duplicatesDeleted > 0 {
            do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
        }
    }

    /// Heals existing data by collapsing duplicate CDMealSuggestion rows
    /// where the same person suggested multiple recipes for the same slot.
    /// Keeps the most recently created one per (suggestedBy, day, mealType).
    /// Preserves distinct suggestions from different household members.
    func dedupeSuggestions() {
        let request = CDMealSuggestion.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMealSuggestion.dateCreated, ascending: false)]
        guard let all = try? viewContext.fetch(request) else { return }

        var seen: [String: CDMealSuggestion] = [:]
        var duplicatesDeleted = 0
        for suggestion in all {
            // Same KVC-read safeguard as dedupeMealPlans() — the Core Data
            // model marks `date` optional, so a synced row could be nil.
            let rawDate = (suggestion.value(forKey: "date") as? Date) ?? Date.distantPast
            let dayStart = DateHelper.stripTime(from: rawDate)
            let key = "\(Self.dedupeFormatter.string(from: dayStart))|\(suggestion.mealTypeRaw)|\(suggestion.suggestedBy.lowercased())"
            if seen[key] != nil {
                viewContext.delete(suggestion)
                duplicatesDeleted += 1
            } else {
                suggestion.date = dayStart
                seen[key] = suggestion
            }
        }
        // TEMP DEBUG — remove before release
        print("[TEMP DEBUG] dedupeSuggestions — scanned=\(all.count) unique=\(seen.count) duplicatesDeleted=\(duplicatesDeleted)")
        if duplicatesDeleted > 0 {
            do {
            try viewContext.save()
        } catch {
            print("[ERROR] Core Data save failed: \(error)")
        }
        }
    }

    // MARK: - Private

    /// Fetches ALL existing meal plans for a specific day and meal type.
    /// Uses a half-open date range [dayStart, nextDay) instead of exact
    /// `date == %@` equality, so sub-second Date drift can't defeat the
    /// lookup and accidentally create a duplicate row.
    private func fetchMealPlans(for dayStart: Date, mealType: MealType) -> [CDMealPlan] {
        guard let nextDayStart = Calendar.current.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }
        let request = CDMealPlan.fetchRequest()
        request.predicate = NSPredicate(
            format: "date >= %@ AND date < %@ AND mealTypeRaw == %@",
            dayStart as NSDate,
            nextDayStart as NSDate,
            mealType.rawValue
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CDMealPlan.date, ascending: true)]
        return (try? viewContext.fetch(request)) ?? []
    }
}
