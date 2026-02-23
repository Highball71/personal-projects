//
//  CRMProject.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// A project that groups related contacts, tasks, and appointments.
/// Named CRMProject to avoid potential namespace collisions.
@Model
final class CRMProject {
    var name: String = ""
    var notes: String = ""
    var status: ProjectStatus = ProjectStatus.active
    var createdAt: Date = Date()

    // A project can involve multiple contacts (many-to-many).
    // Deleting a project doesn't delete its contacts.
    @Relationship(deleteRule: .nullify)
    var contacts: [Contact]?

    // Deleting a project deletes its tasks.
    @Relationship(deleteRule: .cascade)
    var tasks: [CRMTask]?

    // Deleting a project keeps appointments but clears their project link.
    @Relationship(deleteRule: .nullify)
    var appointments: [Appointment]?

    // MARK: - Convenience Accessors

    var contactsList: [Contact] {
        get { contacts ?? [] }
        set { contacts = newValue }
    }

    var tasksList: [CRMTask] {
        get { tasks ?? [] }
        set { tasks = newValue }
    }

    var appointmentsList: [Appointment] {
        get { appointments ?? [] }
        set { appointments = newValue }
    }

    init(
        name: String,
        notes: String = "",
        status: ProjectStatus = .active
    ) {
        self.name = name
        self.notes = notes
        self.status = status
        self.createdAt = Date()
    }
}
