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

struct RecipeRow: Codable, Identifiable {
    let id: UUID
    let householdID: UUID
    let name: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case householdID = "household_id"
        case createdAt = "created_at"
    }
}

struct RecipeInsert: Codable {
    let householdID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case name
        case householdID = "household_id"
    }
}

// MARK: - Recipe Ingredients

struct RecipeIngredientRow: Codable, Identifiable {
    let id: UUID
    let recipeID: UUID
    let name: String
    let quantity: Double
    let unit: String

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit
        case recipeID = "recipe_id"
    }
}

struct RecipeIngredientInsert: Codable {
    var recipeID: UUID?
    let name: String
    let quantity: Double
    let unit: String

    enum CodingKeys: String, CodingKey {
        case name, quantity, unit
        case recipeID = "recipe_id"
    }
}

// MARK: - Meal Plans

struct MealPlanRow: Codable, Identifiable {
    let id: UUID
    let householdID: UUID
    let recipeID: UUID?
    let date: String  // ISO date string "YYYY-MM-DD"
    let mealType: String

    enum CodingKeys: String, CodingKey {
        case id, date
        case householdID = "household_id"
        case recipeID = "recipe_id"
        case mealType = "meal_type"
    }
}

// MARK: - Grocery Items

struct SBGroceryItem: Codable, Identifiable {
    let id: UUID
    let householdID: UUID
    let itemID: String
    let name: String
    let totalQuantity: Double
    let unit: String
    let isChecked: Bool
    let weekStart: String?

    enum CodingKeys: String, CodingKey {
        case id, name, unit
        case householdID = "household_id"
        case itemID = "item_id"
        case totalQuantity = "total_quantity"
        case isChecked = "is_checked"
        case weekStart = "week_start"
    }
}
