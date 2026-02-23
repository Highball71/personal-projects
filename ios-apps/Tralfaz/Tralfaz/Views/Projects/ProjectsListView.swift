//
//  ProjectsListView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows all projects sorted by name, with search, add, and swipe-to-delete.
struct ProjectsListView: View {
    @Query(sort: \CRMProject.name) private var projects: [CRMProject]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddProject = false
    @State private var searchText = ""

    private var filteredProjects: [CRMProject] {
        guard !searchText.isEmpty else { return projects }
        let query = searchText.lowercased()
        return projects.filter { project in
            project.name.lowercased().contains(query)
            || project.notes.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredProjects) { project in
                    NavigationLink(value: project) {
                        ProjectRowView(project: project)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
            .navigationTitle("Projects")
            .navigationDestination(for: CRMProject.self) { project in
                ProjectDetailView(project: project)
            }
            .searchable(text: $searchText, prompt: "Search projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddProject = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddProject) {
                AddEditProjectView()
            }
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects Yet",
                        systemImage: "folder",
                        description: Text("Tap + to create your first project.")
                    )
                } else if filteredProjects.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                }
            }
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredProjects[index])
        }
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: CRMProject.self, inMemory: true)
}
