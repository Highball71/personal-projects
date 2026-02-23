//
//  TasksListView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows all tasks sorted by due date.
struct TasksListView: View {
    @Query(sort: \CRMTask.dueDate) private var tasks: [CRMTask]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    Text(task.title)
                }
            }
            .navigationTitle("Tasks")
            .overlay {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Tap + to add your first task.")
                    )
                }
            }
        }
    }
}

#Preview {
    TasksListView()
        .modelContainer(for: CRMTask.self, inMemory: true)
}
