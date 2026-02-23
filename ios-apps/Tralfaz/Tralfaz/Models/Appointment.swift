//
//  Appointment.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// A scheduled meeting or event, linked to one or more contacts
/// and optionally to a project.
@Model
final class Appointment {
    var title: String = ""
    var notes: String = ""
    var location: String = ""
    var date: Date = Date()
    var endDate: Date?
    var createdAt: Date = Date()

    // An appointment can involve multiple contacts (many-to-many).
    @Relationship(inverse: \Contact.appointments)
    var contacts: [Contact]?

    @Relationship(inverse: \CRMProject.appointments)
    var project: CRMProject?

    /// Non-optional accessor for the contacts array.
    var contactsList: [Contact] {
        get { contacts ?? [] }
        set { contacts = newValue }
    }

    init(
        title: String,
        notes: String = "",
        location: String = "",
        date: Date = Date(),
        endDate: Date? = nil,
        contacts: [Contact] = [],
        project: CRMProject? = nil
    ) {
        self.title = title
        self.notes = notes
        self.location = location
        self.date = date
        self.endDate = endDate
        self.contacts = contacts
        self.project = project
        self.createdAt = Date()
    }
}
