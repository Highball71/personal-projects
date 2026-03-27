//
//  CDHousehold+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the Household entity.
//  This is the root object that gets shared via CloudKit.
//

import Foundation
import CoreData

@objc(CDHousehold)
public class CDHousehold: NSManagedObject {}

extension CDHousehold {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDHousehold> {
        return NSFetchRequest<CDHousehold>(entityName: "CDHousehold")
    }

    /// Unique identifier for this household.
    @NSManaged public var id: UUID

    /// Display name for the household (e.g. "Albert Family").
    @NSManaged public var name: String

    /// Recipes that belong to this household.
    @NSManaged public var recipes: NSSet?

    /// Members of this household.
    @NSManaged public var members: NSSet?
}

// MARK: - Relationship helpers

extension CDHousehold {
    @objc(addRecipesObject:)
    @NSManaged public func addToRecipes(_ value: CDRecipe)

    @objc(removeRecipesObject:)
    @NSManaged public func removeFromRecipes(_ value: CDRecipe)

    @objc(addRecipes:)
    @NSManaged public func addToRecipes(_ values: NSSet)

    @objc(removeRecipes:)
    @NSManaged public func removeFromRecipes(_ values: NSSet)

    @objc(addMembersObject:)
    @NSManaged public func addToMembers(_ value: CDHouseholdMember)

    @objc(removeMembersObject:)
    @NSManaged public func removeFromMembers(_ value: CDHouseholdMember)

    @objc(addMembers:)
    @NSManaged public func addToMembers(_ values: NSSet)

    @objc(removeMembers:)
    @NSManaged public func removeFromMembers(_ values: NSSet)
}

extension CDHousehold: Identifiable {}
