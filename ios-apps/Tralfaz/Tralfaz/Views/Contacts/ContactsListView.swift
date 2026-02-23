//
//  ContactsListView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows all contacts sorted by last name.
struct ContactsListView: View {
    @Query(sort: \Contact.lastName) private var contacts: [Contact]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(contacts) { contact in
                    Text(contact.displayName)
                }
            }
            .navigationTitle("Contacts")
            .overlay {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts Yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add your first contact.")
                    )
                }
            }
        }
    }
}

#Preview {
    ContactsListView()
        .modelContainer(for: Contact.self, inMemory: true)
}
