//
//  TaskRowView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI

/// A single row in the tasks list with a tappable checkbox, title,
/// priority indicator, and optional due date.
struct TaskRowView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var task: CRMTask

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox toggle
            Button {
                task.isCompleted.toggle()
                task.completedAt = task.isCompleted ? Date() : nil
                NotificationScheduler.rescheduleAll(modelContext: modelContext)
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Title and linked contact
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let contact = task.contact {
                    Text(contact.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Due date (red if overdue and not completed)
            if let dueDate = task.dueDate {
                Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(isOverdue(dueDate) ? .red : .secondary)
            }

            // Priority indicator dot
            Circle()
                .fill(priorityColor)
                .frame(width: 10, height: 10)
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }

    /// A task is overdue if the due date is in the past and it's not completed.
    private func isOverdue(_ date: Date) -> Bool {
        !task.isCompleted && date < Calendar.current.startOfDay(for: Date())
    }
}
