//
//  TaskDetailView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Read-only detail view for a task with edit, delete, and completion toggle.
struct TaskDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var task: CRMTask

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            taskInfoSection
            linkSection
            statusSection
            deleteSection
        }
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditTaskView(taskToEdit: task)
        }
        .alert("Delete this task?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(task)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Sections

    private var taskInfoSection: some View {
        Section("Task Info") {
            LabeledContent("Priority", value: task.priority.rawValue)

            if let dueDate = task.dueDate {
                LabeledContent("Due Date") {
                    Text(dueDate.formatted(date: .long, time: .omitted))
                        .foregroundStyle(isOverdue(dueDate) ? .red : .primary)
                }
            }

            if !task.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(task.notes)
                }
            }
        }
    }

    @ViewBuilder
    private var linkSection: some View {
        let hasLinks = task.contact != nil || task.project != nil
        if hasLinks {
            Section("Linked To") {
                if let contact = task.contact {
                    LabeledContent("Contact", value: contact.displayName)
                }
                if let project = task.project {
                    LabeledContent("Project", value: project.name)
                }
            }
        }
    }

    private var statusSection: some View {
        Section("Status") {
            if task.isCompleted, let completedAt = task.completedAt {
                LabeledContent(
                    "Completed",
                    value: completedAt.formatted(date: .abbreviated, time: .omitted)
                )
            }

            Button {
                task.isCompleted.toggle()
                task.completedAt = task.isCompleted ? Date() : nil
            } label: {
                Label(
                    task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                    systemImage: task.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle"
                )
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Task", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        !task.isCompleted && date < Calendar.current.startOfDay(for: Date())
    }
}
