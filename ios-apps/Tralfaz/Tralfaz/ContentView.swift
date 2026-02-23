//
//  ContentView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Root view with four tabs matching the CRM's core features.
struct ContentView: View {
    var body: some View {
        TabView {
            ContactsListView()
                .tabItem {
                    Label("Contacts", systemImage: "person.2")
                }

            TasksListView()
                .tabItem {
                    Label("Tasks", systemImage: "checklist")
                }

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }

            ProjectsListView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [Contact.self, CRMTask.self, Appointment.self, CRMProject.self],
            inMemory: true
        )
}
