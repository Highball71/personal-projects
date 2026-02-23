//
//  ContactDetailView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Read-only detail view for a contact. Only shows sections/fields
/// that have data, so the view stays clean.
struct ContactDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let contact: Contact

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            contactInfoSection
            personalSection
            tagsSection
            socialSection
            notesSection
            trackingSection
            deleteSection
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditContactView(contactToEdit: contact)
        }
        .alert("Delete this contact?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(contact)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will also delete all tasks linked to this contact. This can't be undone.")
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var contactInfoSection: some View {
        let hasInfo = !contact.phone.isEmpty || !contact.email.isEmpty || !contact.company.isEmpty
        if hasInfo {
            Section("Contact Info") {
                if !contact.phone.isEmpty {
                    LabeledContent("Phone", value: contact.phone)
                }
                if !contact.email.isEmpty {
                    LabeledContent("Email", value: contact.email)
                }
                if !contact.company.isEmpty {
                    LabeledContent("Company", value: contact.company)
                }
            }
        }
    }

    @ViewBuilder
    private var personalSection: some View {
        Section("Personal") {
            LabeledContent("Relationship", value: contact.relationshipType.rawValue)

            if let birthday = contact.birthday {
                LabeledContent("Birthday", value: birthday.formatted(date: .long, time: .omitted))
            }

            if !contact.howWeMet.isEmpty {
                LabeledContent("How We Met", value: contact.howWeMet)
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        if !contact.tags.isEmpty {
            Section("Tags") {
                FlowLayout(spacing: 8) {
                    ForEach(contact.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.blue.opacity(0.15))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    @ViewBuilder
    private var socialSection: some View {
        let hasSocial = !contact.linkedInURL.isEmpty || !contact.twitterHandle.isEmpty || !contact.instagramHandle.isEmpty
        if hasSocial {
            Section("Social") {
                if !contact.linkedInURL.isEmpty {
                    LabeledContent("LinkedIn", value: contact.linkedInURL)
                }
                if !contact.twitterHandle.isEmpty {
                    LabeledContent("Twitter / X", value: contact.twitterHandle)
                }
                if !contact.instagramHandle.isEmpty {
                    LabeledContent("Instagram", value: contact.instagramHandle)
                }
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if !contact.notes.isEmpty {
            Section("Notes") {
                Text(contact.notes)
            }
        }
    }

    private var trackingSection: some View {
        Section("Tracking") {
            if let lastContacted = contact.lastContactedDate {
                LabeledContent("Last Contacted", value: lastContacted.formatted(date: .abbreviated, time: .omitted))
            }

            Button("Mark Contacted Today") {
                contact.lastContactedDate = Date()
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Contact", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }
}
