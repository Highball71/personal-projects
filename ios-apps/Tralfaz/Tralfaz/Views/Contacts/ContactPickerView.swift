//
//  ContactPickerView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// A searchable multi-select contact picker. Selected contacts appear as
/// removable chips; a search field filters remaining contacts to add.
struct ContactPickerView: View {
    @Binding var selectedContacts: [Contact]
    @Query(sort: \Contact.lastName) private var allContacts: [Contact]

    @State private var searchText = ""

    /// Contacts not yet selected, filtered by search text.
    private var availableContacts: [Contact] {
        let unselected = allContacts.filter { contact in
            !selectedContacts.contains(where: { $0.id == contact.id })
        }
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return unselected.filter { contact in
            contact.firstName.lowercased().contains(query)
            || contact.lastName.lowercased().contains(query)
            || contact.company.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected contacts as removable chips
            if !selectedContacts.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(selectedContacts) { contact in
                        TagChip(title: contact.displayName) {
                            selectedContacts.removeAll { $0.id == contact.id }
                        }
                    }
                }
            }

            // Search field
            TextField("Search contacts...", text: $searchText)

            // Search results
            if !availableContacts.isEmpty {
                ForEach(availableContacts) { contact in
                    Button {
                        selectedContacts.append(contact)
                        searchText = ""
                    } label: {
                        HStack {
                            Text(contact.displayName)
                                .foregroundStyle(.primary)
                            if !contact.company.isEmpty {
                                Text("· \(contact.company)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
