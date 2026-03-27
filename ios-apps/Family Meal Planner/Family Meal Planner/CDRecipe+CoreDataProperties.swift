//
//  CDRecipe+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the Recipe entity.
//

import Foundation
import CoreData

@objc(CDRecipe)
public class CDRecipe: NSManagedObject {}

extension CDRecipe {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDRecipe> {
        return NSFetchRequest<CDRecipe>(entityName: "CDRecipe")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Recipe name.
    @NSManaged public var name: String

    /// Recipe category (stored as raw string).
    @NSManaged public var categoryRaw: String

    /// Number of servings.
    @NSManaged public var servings: Int16

    /// Preparation time in minutes.
    @NSManaged public var prepTimeMinutes: Int16

    /// Cooking time in minutes.
    @NSManaged public var cookTimeMinutes: Int16

    /// Recipe instructions.
    @NSManaged public var instructions: String

    /// Date the recipe was created.
    @NSManaged public var dateCreated: Date

    /// Whether the recipe is marked as a favorite.
    @NSManaged public var isFavorite: Bool

    /// Recipe source type (stored as raw string).
    @NSManaged public var sourceTypeRaw: String?

    /// Additional source details (URL, cookbook name, etc.).
    @NSManaged public var sourceDetail: String?

    /// Name of the person who added this recipe.
    @NSManaged public var addedByName: String?

    /// Ingredients in this recipe.
    @NSManaged public var ingredients: NSSet?

    /// Meal plan entries that reference this recipe.
    @NSManaged public var mealPlans: NSSet?

    /// Ratings for this recipe.
    @NSManaged public var ratings: NSSet?

    /// Meal suggestions that reference this recipe.
    @NSManaged public var suggestions: NSSet?

    /// The household this recipe belongs to.
    @NSManaged public var household: CDHousehold?
}

// MARK: - Computed Properties

extension CDRecipe {
    /// The recipe category as an enum.
    var category: RecipeCategory {
        get {
            return RecipeCategory(rawValue: categoryRaw) ?? .dinner
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }

    /// The recipe source type as an enum.
    var sourceType: RecipeSource? {
        get {
            guard let raw = sourceTypeRaw else { return nil }
            return RecipeSource(rawValue: raw)
        }
        set {
            sourceTypeRaw = newValue?.rawValue
        }
    }

    /// Ingredients as an ordered array.
    var ingredientsList: [CDIngredient] {
        return (ingredients as? Set<CDIngredient>)?.sorted(by: { $0.name < $1.name }) ?? []
    }

    /// Ratings as an ordered array.
    var ratingsList: [CDRecipeRating] {
        return (ratings as? Set<CDRecipeRating>)?.sorted(by: { $0.dateRated < $1.dateRated }) ?? []
    }

    /// Average rating across all ratings.
    var averageRating: Double? {
        let ratings = ratingsList
        guard !ratings.isEmpty else { return nil }
        let sum = ratings.reduce(0) { $0 + Double($1.rating) }
        return sum / Double(ratings.count)
    }
}

// MARK: - Relationship Helpers

extension CDRecipe {
    @objc(addIngredientsObject:)
    @NSManaged public func addToIngredients(_ value: CDIngredient)

    @objc(removeIngredientsObject:)
    @NSManaged public func removeFromIngredients(_ value: CDIngredient)

    @objc(addIngredients:)
    @NSManaged public func addToIngredients(_ values: NSSet)

    @objc(removeIngredients:)
    @NSManaged public func removeFromIngredients(_ values: NSSet)

    @objc(addMealPlansObject:)
    @NSManaged public func addToMealPlans(_ value: CDMealPlan)

    @objc(removeMealPlansObject:)
    @NSManaged public func removeFromMealPlans(_ value: CDMealPlan)

    @objc(addMealPlans:)
    @NSManaged public func addToMealPlans(_ values: NSSet)

    @objc(removeMealPlans:)
    @NSManaged public func removeFromMealPlans(_ values: NSSet)

    @objc(addRatingsObject:)
    @NSManaged public func addToRatings(_ value: CDRecipeRating)

    @objc(removeRatingsObject:)
    @NSManaged public func removeFromRatings(_ value: CDRecipeRating)

    @objc(addRatings:)
    @NSManaged public func addToRatings(_ values: NSSet)

    @objc(removeRatings:)
    @NSManaged public func removeFromRatings(_ values: NSSet)

    @objc(addSuggestionsObject:)
    @NSManaged public func addToSuggestions(_ value: CDMealSuggestion)

    @objc(removeSuggestionsObject:)
    @NSManaged public func removeFromSuggestions(_ value: CDMealSuggestion)

    @objc(addSuggestions:)
    @NSManaged public func addToSuggestions(_ values: NSSet)

    @objc(removeSuggestions:)
    @NSManaged public func removeFromSuggestions(_ values: NSSet)
}

extension CDRecipe: Identifiable {}
