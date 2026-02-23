//
//  AddEditTaskView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// A form for creating or editing a task. Pass a task to edit it,
/// or leave nil to create a new one.
struct AddEditTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Nil = add mode, non-nil = edit mode.
    var taskToEdit: CRMTask?

    // All contacts and projects for the pickers
    @Query(sort: \Contact.lastName) private var allContacts: [Contact]
    @Query(sort: \CRMProject.name) private var allProjects: [CRMProject]

    // MARK: - Form State

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var selectedContact: Contact?
    @State private var selectedProject: CRMProject?

    private var isEditing: Bool { taskToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                taskSection
                detailsSection
                linkSection
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTask() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                populateFormForEditing()
            }
        }
    }

    // MARK: - Form Sections

    private var taskSection: some View {
        Section("Task") {
            TextField("Title", text: $title)
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }

    private var detailsSection: some View {
        Section("Details") {
            Picker("Priority", selection: $priority) {
                ForEach(TaskPriority.allCases) { p in
                    Text(p.rawValue).tag(p)
                }
            }

            Toggle("Due Date", isOn: $hasDueDate)
            if hasDueDate {
                DatePicker(
                    "Date",
                    selection: $dueDate,
                    displayedComponents: .date
                )
            }
        }
    }

    private var linkSection: some View {
        Section("Link To") {
            // Contact picker
            Picker("Contact", selection: $selectedContact) {
                Text("None").tag(Contact?.none)
                ForEach(allContacts) { contact in
                    Text(contact.displayName).tag(Contact?.some(contact))
                }
            }

            // Project picker
            Picker("Project", selection: $selectedProject) {
                Text("None").tag(CRMProject?.none)
                ForEach(allProjects) { project in
                    Text(project.name).tag(CRMProject?.some(project))
                }
            }
        }
    }

    // MARK: - Data Handling

    private func populateFormForEditing() {
        guard let task = taskToEdit else { return }

        title = task.title
        notes = task.notes
        priority = task.priority
        selectedContact = task.contact
        selectedProject = task.project

        if let due = task.dueDate {
            hasDueDate = true
            dueDate = due
        }
    }

    private func saveTask() {
        if let task = taskToEdit {
            // Update existing
            task.title = title
            task.notes = notes
            task.priority = priority
            task.dueDate = hasDueDate ? dueDate : nil
            task.contact = selectedContact
            task.project = selectedProject
        } else {
            // Create new
            let task = CRMTask(
                title: title,
                notes: notes,
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority,
                contact: selectedContact,
                project: selectedProject
            )
            modelContext.insert(task)
        }

        dismiss()
    }
}

#Preview {
    AddEditTaskView()
        .modelContainer(
            for: [CRMTask.self, Contact.self, CRMProject.self],
            inMemory: true
        )
}
