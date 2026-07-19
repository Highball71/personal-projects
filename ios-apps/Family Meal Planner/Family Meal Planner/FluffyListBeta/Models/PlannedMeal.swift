//
//  PlannedMeal.swift
//  FluffyList
//
//  Multiple-meals-per-day model. A PlannedMeal is one recipe assigned
//  to a specific (date, mealType) on a household's calendar. A day is
//  a collection of PlannedMeals; a meal type within a day can also
//  contain multiple PlannedMeals.
//
//  Persistence: the `meal_plans` Supabase table (see migration
//  010_planned_meals.sql). PlannedMealRow mirrors the DB columns,
//  PlannedMeal is the Swift domain type used by view models and UI.
//
//  Note on naming: the legacy CloudKit path still defines a top-level
//  `MealType` with different cases and raw values (Models/MealType.swift).
//  To avoid a collision while it's still around, the new enum is nested
//  as `PlannedMeal.MealType` and always referenced that way.
//

import Foundation

// MARK: - PlannedMeal (domain)

/// One recipe scheduled into a (date, mealType) slot.
/// This is the type view models and views work with.
struct PlannedMeal: Identifiable, Codable, Equatable {

    // MARK: MealType

    /// The meal slot a PlannedMeal belongs to within a day.
    /// Raw values match the `meal_plans.meal_type` column.
    enum MealType: String, CaseIterable, Codable, Identifiable {
        case breakfast
        case lunch
        case dinner
        case snacks
        case other

        var id: String { rawValue }

        /// Display order used when showing a day's sections.
        static let displayOrder: [PlannedMeal.MealType] = [
            .breakfast, .lunch, .dinner, .snacks, .other
        ]

        /// Title-cased label for UI ("Breakfast", "Lunch", etc.).
        var displayName: String {
            rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    // MARK: Properties

    let id: UUID
    let date: Date
    let mealType: MealType
    let recipeId: UUID
    let sortOrder: Int
    let createdAt: Date
}

// MARK: - PlannedMealRow (Supabase read)

/// Codable mirror of the `meal_plans` row as returned by PostgREST.
///
/// The `date` column is a SQL DATE, which Postgres serialises as
/// "YYYY-MM-DD" — not a valid ISO 8601 timestamp, so we keep it as
/// String and convert in `toDomain()`.
///
/// `recipeID` is optional because meal_plans.recipe_id has
/// `on delete set null` — a row whose recipe was deleted will have
/// NULL here and should be filtered out by the caller.
struct PlannedMealRow: Codable, Identifiable, Equatable {
    let id: UUID
    let householdID: UUID
    let recipeID: UUID?
    let date: String
    let mealType: String
    let sortOrder: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, date
        case householdID = "household_id"
        case recipeID = "recipe_id"
        case mealType = "meal_type"
        case sortOrder = "sort_order"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        householdID = try c.decode(UUID.self, forKey: .householdID)
        recipeID    = try? c.decode(UUID.self, forKey: .recipeID)
        date        = (try? c.decode(String.self, forKey: .date)) ?? ""
        mealType    = (try? c.decode(String.self, forKey: .mealType)) ?? "dinner"
        sortOrder   = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
        createdAt   = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }

    /// Convert to the domain type. Returns nil if the row is missing
    /// a recipe (orphaned by a recipe delete) or the date string can't
    /// be parsed.
    func toDomain() -> PlannedMeal? {
        guard let recipeID else { return nil }
        guard let parsedDate = Self.dateFormatter.date(from: date) else { return nil }
        let type = PlannedMeal.MealType(rawValue: mealType) ?? .other
        return PlannedMeal(
            id: id,
            date: parsedDate,
            mealType: type,
            recipeId: recipeID,
            sortOrder: sortOrder,
            createdAt: createdAt
        )
    }

    /// Canonical formatter for the Postgres DATE column.
    ///
    /// Timezone is deliberately `Calendar.current.timeZone` (the user's
    /// **local** zone), not UTC. The rest of the pipeline works in
    /// local time — `Calendar.current.startOfDay(for: Date())` produces
    /// local midnight, `DateHelper.startOfWeek` returns local midnight,
    /// and `PlannedMealViewModel` groups on `Calendar.current.startOfDay`.
    /// A UTC formatter here would silently shift local midnight across
    /// the date boundary (e.g. `2026-04-23 00:00 UTC+2` → `"2026-04-22"`),
    /// so a meal added "today" could save under yesterday's DATE.
    ///
    /// Using the local zone means local midnight always round-trips to
    /// the same `YYYY-MM-DD`, and the fetched value parses back to the
    /// same local-midnight `Date` the grouping key expects.
    ///
    /// POSIX locale keeps the numeric format stable across device
    /// locales.
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = Calendar.current.timeZone
        return f
    }()
}

// MARK: - PlannedMealInsert (Supabase write)

/// Codable payload for inserting a new planned meal. Omits
/// server-generated columns (`id`, `created_at`).
struct PlannedMealInsert: Codable {
    let householdID: UUID
    let recipeID: UUID
    /// ISO date string "YYYY-MM-DD"
    let date: String
    let mealType: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case date
        case householdID = "household_id"
        case recipeID = "recipe_id"
        case mealType = "meal_type"
        case sortOrder = "sort_order"
    }
}
