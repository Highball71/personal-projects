//
//  CDGroceryItem+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the GroceryItem entity.
//

import Foundation
import CoreData

@objc(CDGroceryItem)
public class CDGroceryItem: NSManagedObject {}

extension CDGroceryItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDGroceryItem> {
        return NSFetchRequest<CDGroceryItem>(entityName: "CDGroceryItem")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Item identifier for grouping related items.
    @NSManaged public var itemID: String

    /// Display name of the grocery item.
    @NSManaged public var name: String

    /// Total quantity across all recipes.
    @NSManaged public var totalQuantity: Double

    /// Unit of measurement (stored as raw string).
    @NSManaged public var unitRaw: String

    /// Whether this item has been checked off the list.
    @NSManaged public var isChecked: Bool

    /// Week start date for this grocery list.
    @NSManaged public var weekStart: Date
}

// MARK: - Computed Properties

extension CDGroceryItem {
    /// The unit as an enum.
    var unit: IngredientUnit {
        get {
            return IngredientUnit(rawValue: unitRaw) ?? .none
        }
        set {
            unitRaw = newValue.rawValue
        }
    }
}

extension CDGroceryItem: Identifiable {}
