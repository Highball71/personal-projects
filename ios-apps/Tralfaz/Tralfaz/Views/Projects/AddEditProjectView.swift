//
//  AddEditProjectView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// A form for creating or editing a project. Pass a project to edit it,
/// or leave nil to create a new one.
struct AddEditProjectView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var projectToEdit: CRMProject?

    // MARK: - Form State

    @State private var name: String = ""
    @State private var status: ProjectStatus = .active
    @State private var selectedContacts: [Contact] = []
    @State private var notes: String = ""

    private var isEditing: Bool { projectToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                projectSection
                statusSection
                contactsSection
                notesSection
            }
            .navigationTitle(isEditing ? "Edit Project" : "New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveProject() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                populateFormForEditing()
            }
        }
    }

    // MARK: - Form Sections

    private var projectSection: some View {
        Section("Project") {
            TextField("Name", text: $name)
        }
    }

    private var statusSection: some View {
        Section("Status") {
            Picker("Status", selection: $status) {
                ForEach(ProjectStatus.allCases) { s in
                    Text(s.rawValue).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var contactsSection: some View {
        Section("Contacts") {
            ContactPickerView(selectedContacts: $selectedContacts)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }

    // MARK: - Data Handling

    private func populateFormForEditing() {
        guard let project = projectToEdit else { return }

        name = project.name
        status = project.status
        selectedContacts = project.contactsList
        notes = project.notes
    }

    private func saveProject() {
        if let project = projectToEdit {
            project.name = name
            project.status = status
            project.contactsList = selectedContacts
            project.notes = notes
        } else {
            let project = CRMProject(
                name: name,
                notes: notes,
                status: status
            )
            project.contactsList = selectedContacts
            modelContext.insert(project)
        }

        dismiss()
    }
}

#Preview {
    AddEditProjectView()
        .modelContainer(
            for: [CRMProject.self, Contact.self],
            inMemory: true
        )
}
