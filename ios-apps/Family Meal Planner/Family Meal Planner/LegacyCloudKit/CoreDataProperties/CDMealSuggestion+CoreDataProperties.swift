//
//  CDMealSuggestion+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the MealSuggestion entity.
//

import Foundation
import CoreData

@objc(CDMealSuggestion)
public class CDMealSuggestion: NSManagedObject {}

extension CDMealSuggestion {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMealSuggestion> {
        return NSFetchRequest<CDMealSuggestion>(entityName: "CDMealSuggestion")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Date for the suggested meal.
    @NSManaged public var date: Date

    /// Type of meal (stored as raw string).
    @NSManaged public var mealTypeRaw: String

    /// Name of the person who suggested this meal.
    @NSManaged public var suggestedBy: String

    /// Date the suggestion was created.
    @NSManaged public var dateCreated: Date

    /// The recipe that was suggested.
    @NSManaged public var recipe: CDRecipe?
}

// MARK: - Computed Properties

extension CDMealSuggestion {
    /// The meal type as an enum.
    var mealType: MealType {
        get {
            return MealType(rawValue: mealTypeRaw) ?? .dinner
        }
        set {
            mealTypeRaw = newValue.rawValue
        }
    }
}

extension CDMealSuggestion: Identifiable {}
