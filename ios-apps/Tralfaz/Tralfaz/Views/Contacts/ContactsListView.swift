//
//  ContactsListView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows all contacts sorted by last name, with search, add, and swipe-to-delete.
struct ContactsListView: View {
    @Query(sort: \Contact.lastName) private var contacts: [Contact]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddContact = false
    @State private var searchText = ""

    /// Contacts filtered by the current search text.
    private var filteredContacts: [Contact] {
        guard !searchText.isEmpty else { return contacts }
        let query = searchText.lowercased()
        return contacts.filter { contact in
            contact.firstName.lowercased().contains(query)
            || contact.lastName.lowercased().contains(query)
            || contact.company.lowercased().contains(query)
            || contact.tagsStorage.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredContacts) { contact in
                    NavigationLink(value: contact) {
                        ContactRowView(contact: contact)
                    }
                }
                .onDelete(perform: deleteContacts)
            }
            .navigationTitle("Contacts")
            .navigationDestination(for: Contact.self) { contact in
                ContactDetailView(contact: contact)
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddContact = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddContact) {
                AddEditContactView()
            }
            .overlay {
                if contacts.isEmpty {
                    ContentUnavailableView(
                        "No Contacts Yet",
                        systemImage: "person.2",
                        description: Text("Tap + to add your first contact.")
                    )
                } else if filteredContacts.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                }
            }
        }
    }

    private func deleteContacts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredContacts[index])
        }
    }
}

#Preview {
    ContactsListView()
        .modelContainer(for: Contact.self, inMemory: true)
}
