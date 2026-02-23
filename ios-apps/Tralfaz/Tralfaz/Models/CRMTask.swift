//
//  CRMTask.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import SwiftData

/// A to-do item, optionally linked to a contact and/or project.
/// Named CRMTask to avoid collision with Swift's built-in Task type.
@Model
final class CRMTask {
    var title: String = ""
    var notes: String = ""
    var dueDate: Date?
    var isCompleted: Bool = false
    var priority: TaskPriority = TaskPriority.medium
    var completedAt: Date?
    var createdAt: Date = Date()

    @Relationship(inverse: \Contact.tasks)
    var contact: Contact?

    @Relationship(inverse: \CRMProject.tasks)
    var project: CRMProject?

    init(
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        priority: TaskPriority = .medium,
        contact: Contact? = nil,
        project: CRMProject? = nil
    ) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.priority = priority
        self.contact = contact
        self.project = project
        self.createdAt = Date()
    }
}
