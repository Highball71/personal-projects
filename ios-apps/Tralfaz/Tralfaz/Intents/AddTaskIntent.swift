//
//  AddTaskIntent.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import AppIntents
import SwiftData

/// Siri Shortcut: "Add a task in Tralfaz"
/// Creates a new CRMTask with a title and optional priority.
struct AddTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Add a Task"
    static var description = IntentDescription("Create a new task in Tralfaz.")

    // Don't open the app — just create the task in the background.
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var taskTitle: String

    @Parameter(title: "Priority", default: .medium)
    var priority: TaskPriorityAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.instance)

        let task = CRMTask(
            title: taskTitle,
            priority: priority.toTaskPriority
        )
        context.insert(task)
        try context.save()

        return .result(dialog: "Added task: \(taskTitle)")
    }
}
