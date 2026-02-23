//
//  ProjectDetailView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Read-only detail view for a project with inline lists of linked
/// contacts, tasks, and appointments.
struct ProjectDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let project: CRMProject

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            infoSection
            contactsSection
            tasksSection
            appointmentsSection
            deleteSection
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditProjectView(projectToEdit: project)
        }
        .alert("Delete this project?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(project)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will also delete all tasks linked to this project. This can't be undone.")
        }
    }

    // MARK: - Sections

    private var infoSection: some View {
        Section("Info") {
            LabeledContent("Status", value: project.status.rawValue)

            if !project.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(project.notes)
                }
            }
        }
    }

    private var contactsSection: some View {
        Section("Contacts") {
            if project.contactsList.isEmpty {
                Text("No contacts linked")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(project.contactsList) { contact in
                    Text(contact.displayName)
                }
            }
        }
    }

    private var tasksSection: some View {
        Section("Tasks") {
            if project.tasksList.isEmpty {
                Text("No tasks yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(project.tasksList) { task in
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                        Text(task.title)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    }
                }
            }
        }
    }

    private var appointmentsSection: some View {
        Section("Appointments") {
            if project.appointmentsList.isEmpty {
                Text("No appointments yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(project.appointmentsList) { appointment in
                    HStack {
                        Text(appointment.title)
                        Spacer()
                        Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Project", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }
}
