//
//  ProjectsListView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows all projects sorted by name.
struct ProjectsListView: View {
    @Query(sort: \CRMProject.name) private var projects: [CRMProject]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    Text(project.name)
                }
            }
            .navigationTitle("Projects")
            .overlay {
                if projects.isEmpty {
                    ContentUnavailableView(
                        "No Projects Yet",
                        systemImage: "folder",
                        description: Text("Tap + to create your first project.")
                    )
                }
            }
        }
    }
}

#Preview {
    ProjectsListView()
        .modelContainer(for: CRMProject.self, inMemory: true)
}
