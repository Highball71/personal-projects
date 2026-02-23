//
//  Contact.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// A person in your network. This is the central hub of the CRM --
/// tasks, appointments, and projects all connect back to contacts.
@Model
final class Contact {
    // MARK: - Basic Info
    var firstName: String = ""
    var lastName: String = ""
    var company: String = ""
    var phone: String = ""
    var email: String = ""

    // MARK: - Personal Details
    var birthday: Date?
    var relationshipType: RelationshipType = RelationshipType.friend
    var howWeMet: String = ""
    var notes: String = ""

    // MARK: - Tags
    // Stored as a comma-separated string for reliable SwiftData persistence
    // and simpler #Predicate filtering. Use the computed `tags` property instead.
    var tagsStorage: String = ""

    // MARK: - Social Links
    var linkedInURL: String = ""
    var twitterHandle: String = ""
    var instagramHandle: String = ""

    // MARK: - Tracking
    var lastContactedDate: Date?
    var createdAt: Date = Date()

    // MARK: - Relationships

    // When you delete a contact, their tasks go too
    // (a task without its contact is meaningless).
    @Relationship(deleteRule: .cascade)
    var tasks: [CRMTask]?

    // Appointments may involve other contacts, so just clear the link.
    @Relationship(deleteRule: .nullify)
    var appointments: [Appointment]?

    // Projects may involve other contacts, so just clear the link.
    @Relationship(deleteRule: .nullify)
    var projects: [CRMProject]?

    // MARK: - Convenience Accessors

    /// Full display name, handling cases where one name is empty.
    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "(No Name)" : full
    }

    /// Tags as an array. Reads from / writes to the comma-separated tagsStorage.
    var tags: [String] {
        get {
            tagsStorage.isEmpty ? [] : tagsStorage.components(separatedBy: ",")
        }
        set {
            tagsStorage = newValue.joined(separator: ",")
        }
    }

    var tasksList: [CRMTask] {
        get { tasks ?? [] }
        set { tasks = newValue }
    }

    var appointmentsList: [Appointment] {
        get { appointments ?? [] }
        set { appointments = newValue }
    }

    var projectsList: [CRMProject] {
        get { projects ?? [] }
        set { projects = newValue }
    }

    init(
        firstName: String = "",
        lastName: String = "",
        company: String = "",
        phone: String = "",
        email: String = "",
        birthday: Date? = nil,
        relationshipType: RelationshipType = .friend,
        howWeMet: String = "",
        notes: String = ""
    ) {
        self.firstName = firstName
        self.lastName = lastName
        self.company = company
        self.phone = phone
        self.email = email
        self.birthday = birthday
        self.relationshipType = relationshipType
        self.howWeMet = howWeMet
        self.notes = notes
        self.createdAt = Date()
    }
}
