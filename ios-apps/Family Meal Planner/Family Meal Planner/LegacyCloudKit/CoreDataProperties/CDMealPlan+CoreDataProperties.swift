//
//  CDMealPlan+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the MealPlan entity.
//

import Foundation
import CoreData

@objc(CDMealPlan)
public class CDMealPlan: NSManagedObject {}

extension CDMealPlan {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDMealPlan> {
        return NSFetchRequest<CDMealPlan>(entityName: "CDMealPlan")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Date of the meal plan entry.
    @NSManaged public var date: Date

    /// Type of meal (stored as raw string).
    @NSManaged public var mealTypeRaw: String

    /// The recipe assigned to this meal plan.
    @NSManaged public var recipe: CDRecipe?
}

// MARK: - Computed Properties

extension CDMealPlan {
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

extension CDMealPlan: Identifiable {}
