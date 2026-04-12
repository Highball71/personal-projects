//
//  CDIngredient+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the Ingredient entity.
//

import Foundation
import CoreData

@objc(CDIngredient)
public class CDIngredient: NSManagedObject {}

extension CDIngredient {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDIngredient> {
        return NSFetchRequest<CDIngredient>(entityName: "CDIngredient")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Ingredient name.
    @NSManaged public var name: String

    /// Quantity of the ingredient.
    @NSManaged public var quantity: Double

    /// Unit of measurement (stored as raw string).
    @NSManaged public var unitRaw: String

    /// The recipe this ingredient belongs to.
    @NSManaged public var recipe: CDRecipe?
}

// MARK: - Computed Properties

extension CDIngredient {
    /// The unit as an enum.
    var unit: IngredientUnit {
        get {
            return IngredientUnit(rawValue: unitRaw) ?? .piece
        }
        set {
            unitRaw = newValue.rawValue
        }
    }
}

extension CDIngredient: Identifiable {}
