//
//  TasksListView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows tasks in two sections: To Do (sorted by priority then due date)
/// and Completed (collapsed by default).
struct TasksListView: View {
    @Query(sort: \CRMTask.createdAt) private var tasks: [CRMTask]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddTask = false
    @State private var searchText = ""
    @State private var showCompleted = true

    // MARK: - Filtered & Sorted Tasks

    private var filteredTasks: [CRMTask] {
        guard !searchText.isEmpty else { return tasks }
        let query = searchText.lowercased()
        return tasks.filter { task in
            task.title.lowercased().contains(query)
            || task.notes.lowercased().contains(query)
        }
    }

    /// Pending tasks sorted: high priority first, then by due date (soonest first),
    /// then tasks without a due date at the end.
    private var pendingTasks: [CRMTask] {
        filteredTasks
            .filter { !$0.isCompleted }
            .sorted { a, b in
                let priorityOrder: [TaskPriority] = [.high, .medium, .low]
                let aPri = priorityOrder.firstIndex(of: a.priority) ?? 0
                let bPri = priorityOrder.firstIndex(of: b.priority) ?? 0
                if aPri != bPri { return aPri < bPri }

                // Both same priority — sort by due date (nil goes last)
                switch (a.dueDate, b.dueDate) {
                case let (aDate?, bDate?): return aDate < bDate
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return false
                }
            }
    }

    private var completedTasks: [CRMTask] {
        filteredTasks.filter { $0.isCompleted }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // To Do section
                Section("To Do") {
                    ForEach(pendingTasks) { task in
                        NavigationLink(value: task) {
                            TaskRowView(task: task)
                        }
                    }
                    .onDelete { offsets in
                        deleteTasks(offsets, from: pendingTasks)
                    }
                }

                // Completed section (collapsible)
                if !completedTasks.isEmpty {
                    Section(isExpanded: $showCompleted) {
                        ForEach(completedTasks) { task in
                            NavigationLink(value: task) {
                                TaskRowView(task: task)
                            }
                        }
                        .onDelete { offsets in
                            deleteTasks(offsets, from: completedTasks)
                        }
                    } header: {
                        Text("Completed (\(completedTasks.count))")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Tasks")
            .navigationDestination(for: CRMTask.self) { task in
                TaskDetailView(task: task)
            }
            .searchable(text: $searchText, prompt: "Search tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddEditTaskView()
            }
            .overlay {
                if tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks Yet",
                        systemImage: "checklist",
                        description: Text("Tap + to add your first task.")
                    )
                } else if filteredTasks.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                }
            }
        }
    }

    private func deleteTasks(_ offsets: IndexSet, from list: [CRMTask]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

#Preview {
    TasksListView()
        .modelContainer(for: CRMTask.self, inMemory: true)
}
