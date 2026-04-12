//
//  CDHouseholdMember+CoreDataProperties.swift
//  Family Meal Planner
//
//  Core Data managed object for the HouseholdMember entity.
//

import Foundation
import CoreData

@objc(CDHouseholdMember)
public class CDHouseholdMember: NSManagedObject {}

extension CDHouseholdMember {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<CDHouseholdMember> {
        return NSFetchRequest<CDHouseholdMember>(entityName: "CDHouseholdMember")
    }

    /// Unique identifier.
    @NSManaged public var id: UUID?

    /// Name of the household member.
    @NSManaged public var name: String

    /// Whether this member is the head cook.
    @NSManaged public var isHeadCook: Bool

    /// The household this member belongs to.
    @NSManaged public var household: CDHousehold?
}

extension CDHouseholdMember: Identifiable {}
