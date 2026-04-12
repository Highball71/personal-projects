//
//  CDRecipeRating+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the RecipeRating entity.
//

import Foundation
import CoreData

@objc(CDRecipeRating)
public class CDRecipeRating: NSManagedObject {}

extension CDRecipeRating {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDRecipeRating> {
        return NSFetchRequest<CDRecipeRating>(entityName: "CDRecipeRating")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Name of the person who rated the recipe.
    @NSManaged public var raterName: String

    /// Rating value (typically 1-5).
    @NSManaged public var rating: Int16

    /// Date the rating was submitted.
    @NSManaged public var dateRated: Date

    /// The recipe that was rated.
    @NSManaged public var recipe: CDRecipe?
}

extension CDRecipeRating: Identifiable {}
