//
//  SupabaseModels.swift
//  FluffyList
//
//  Codable structs for Supabase PostgREST.
//  These mirror the SQL schema in supabase/migrations/001_initial_schema.sql.
//
//  Naming convention:
//    - *Row: read from DB (all columns)
//    - *Insert: write to DB (omit server-generated columns)
//

import Foundation

// MARK: - Households

struct HouseholdRow: Codable, Identifiable {
    let id: UUID
    let name: String
    let joinCode: String?
    let ownerID: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case joinCode = "join_code"
        case ownerID = "owner_id"
        case createdAt = "created_at"
    }
}

struct HouseholdInsert: Codable {
    let name: String
    let ownerID: UUID

    enum CodingKeys: String, CodingKey {
        case name
        case ownerID = "owner_id"
    }
}

// MARK: - Household Members

struct HouseholdMemberRow: Codable, Identifiable {
    let id: UUID
    let householdID: UUID
    let userID: UUID
    let displayName: String
    let isHeadCook: Bool
    let joinedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case householdID = "household_id"
        case userID = "user_id"
        case displayName = "display_name"
        case isHeadCook = "is_head_cook"
        case joinedAt = "joined_at"
    }
}

struct HouseholdMemberInsert: Codable {
    let householdID: UUID
    let userID: UUID
    let displayName: String
    let isHeadCook: Bool

    enum CodingKeys: String, CodingKey {
        case householdID = "household_id"
        case userID = "user_id"
        case displayName = "display_name"
        case isHeadCook = "is_head_cook"
    }
}

// MARK: - Recipes

struct RecipeRow: Codable, Identifiable, Equatable {
    let id: UUID
    let householdID: UUID
    let name: String
    let category: String
    let servings: Int
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int
    let instructions: String
    let notes: String
    let isFavorite: Bool
    let sourceType: String?
    let sourceDetail: String?
    let sourceImagePath: String?
    let homemadeImagePath: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, category, servings, instructions, notes
        case householdID = "household_id"
        case prepTimeMinutes = "prep_time_minutes"
        case cookTimeMinutes = "cook_time_minutes"
        case isFavorite = "is_favorite"
        case sourceType = "source_type"
        case sourceDetail = "source_detail"
        case sourceImagePath = "source_image_path"
        case homemadeImagePath = "homemade_image_path"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self, forKey: .id)
        householdID    = try c.decode(UUID.self, forKey: .householdID)
        name           = try c.decode(String.self, forKey: .name)
        createdAt      = try c.decode(Date.self, forKey: .createdAt)
        // New columns — fall back to defaults if missing from response
        category       = (try? c.decode(String.self, forKey: .category)) ?? "dinner"
        servings       = (try? c.decode(Int.self, forKey: .servings)) ?? 4
        prepTimeMinutes = (try? c.decode(Int.self, forKey: .prepTimeMinutes)) ?? 0
        cookTimeMinutes = (try? c.decode(Int.self, forKey: .cookTimeMinutes)) ?? 0
        instructions   = (try? c.decode(String.self, forKey: .instructions)) ?? ""
        notes          = (try? c.decode(String.self, forKey: .notes)) ?? ""
        isFavorite     = (try? c.decode(Bool.self, forKey: .isFavorite)) ?? false
        sourceType     = try? c.decode(String.self, forKey: .sourceType)
        sourceDetail   = try? c.decode(String.self, forKey: .sourceDetail)
        sourceImagePath = try? c.decode(String.self, forKey: .sourceImagePath)
        homemadeImagePath = try? c.decode(String.self, forKey: .homemadeImagePath)
    }

    /// Map the Supabase category string to the existing RecipeCategory enum.
    var recipeCategory: RecipeCategory {
        RecipeCategory(rawValue: category) ?? .dinner
    }
}

struct RecipeInsert: Codable {
    let householdID: UUID
    let name: String
    let category: String
    let servings: Int
    let prepTimeMinutes: Int
    let cookTimeMinutes: Int
    let instructions: String
    let notes: String
    let sourceType: String?
    let sourceDetail: String?
    let sourceImagePath: String?

    enum CodingKeys: String, CodingKey {
        case name, category, servings, instructions, notes
        case householdID = "household_id"
        case prepTimeMinutes = "prep_time_minutes"
        case cookTimeMinutes = "cook_time_minutes"
        case sourceType = "source_type"
        case sourceDetail = "source_detail"
        case sourceImagePath = "source_image_path"
    }
}

// MARK: - Recipe Ingredients

struct RecipeIngredientRow: Codable, Identifiable {
    let id: UUID
    let recipeID: UUID
    let name: String
    let quantity: Double
    let unit: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit
        case recipeID = "recipe_id"
        case sortOrder = "sort_order"
    }
}

struct RecipeIngredientInsert: Codable {
    var recipeID: UUID?
    let name: String
    let quantity: Double
    let unit: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit
        case recipeID = "recipe_id"
        case sortOrder = "sort_order"
    }
}

// MARK: - Meal Plans

struct MealPlanRow: Codable, Identifiable, Equatable {
    let id: UUID
    let householdID: UUID
    let recipeID: UUID?
    /// ISO date string "YYYY-MM-DD" — Postgres returns date columns
    /// in this format, which isn't a valid ISO 8601 timestamp so we
    /// keep it as String and convert in Swift when needed.
    let date: String

    enum CodingKeys: String, CodingKey {
        case id, date
        case householdID = "household_id"
        case recipeID = "recipe_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        householdID = try c.decode(UUID.self, forKey: .householdID)
        recipeID = try? c.decode(UUID.self, forKey: .recipeID)
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
    }
}

struct MealPlanInsert: Codable {
    let householdID: UUID
    let recipeID: UUID
    /// ISO date string "YYYY-MM-DD"
    let date: String

    enum CodingKeys: String, CodingKey {
        case date
        case householdID = "household_id"
        case recipeID = "recipe_id"
    }
}

// MARK: - Grocery Items

struct SupabaseGroceryItem: Codable, Identifiable, Equatable {
    let id: UUID
    let householdID: UUID
    let name: String
    let quantity: Double
    let unit: String
    let isChecked: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit
        case householdID = "household_id"
        case isChecked = "is_checked"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        householdID = try c.decode(UUID.self, forKey: .householdID)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        quantity = (try? c.decode(Double.self, forKey: .quantity)) ?? 1.0
        unit = (try? c.decode(String.self, forKey: .unit)) ?? "piece"
        isChecked = (try? c.decode(Bool.self, forKey: .isChecked)) ?? false
        createdAt = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
    }
}

struct GroceryItemInsert: Codable {
    let householdID: UUID
    let name: String
    let quantity: Double
    let unit: String

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit
        case householdID = "household_id"
    }
}

// MARK: - Grocery Contributions

/// Records how much a specific meal_plan contributed to a specific
/// grocery_item. When the meal plan is cleared or replaced, we can
/// subtract exactly the right amount from the grocery item.
struct GroceryContributionRow: Codable, Identifiable {
    let id: UUID
    let groceryItemID: UUID
    let mealPlanID: UUID
    let quantity: Double

    enum CodingKeys: String, CodingKey {
        case id, quantity
        case groceryItemID = "grocery_item_id"
        case mealPlanID = "meal_plan_id"
    }
}

struct GroceryContributionInsert: Codable {
    let groceryItemID: UUID
    let mealPlanID: UUID
    let quantity: Double

    enum CodingKeys: String, CodingKey {
        case quantity
        case groceryItemID = "grocery_item_id"
        case mealPlanID = "meal_plan_id"
    }
}
