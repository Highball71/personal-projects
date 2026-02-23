//
//  AddEditContactView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// A form for creating or editing a contact. Pass a contact to edit it,
/// or leave nil to create a new one.
struct AddEditContactView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Nil = add mode, non-nil = edit mode.
    var contactToEdit: Contact?

    // MARK: - Form State (local copies, saved only on tap of Save)

    // Name
    @State private var firstName: String = ""
    @State private var lastName: String = ""

    // Contact Info
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var company: String = ""

    // Personal
    @State private var hasBirthday: Bool = false
    @State private var birthday: Date = Date()
    @State private var relationshipType: RelationshipType = .friend
    @State private var howWeMet: String = ""

    // Tags
    @State private var tags: [String] = []

    // Social
    @State private var linkedInURL: String = ""
    @State private var twitterHandle: String = ""
    @State private var instagramHandle: String = ""

    // Notes
    @State private var notes: String = ""

    private var isEditing: Bool { contactToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                nameSection
                contactInfoSection
                personalSection
                tagsSection
                socialSection
                notesSection
            }
            .navigationTitle(isEditing ? "Edit Contact" : "New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveContact() }
                        .disabled(firstName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                populateFormForEditing()
            }
        }
    }

    // MARK: - Form Sections

    private var nameSection: some View {
        Section("Name") {
            TextField("First Name", text: $firstName)
                .textContentType(.givenName)
            TextField("Last Name", text: $lastName)
                .textContentType(.familyName)
        }
    }

    private var contactInfoSection: some View {
        Section("Contact Info") {
            TextField("Phone", text: $phone)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
            TextField("Email", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
            TextField("Company", text: $company)
                .textContentType(.organizationName)
        }
    }

    private var personalSection: some View {
        Section("Personal") {
            Picker("Relationship", selection: $relationshipType) {
                ForEach(RelationshipType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            Toggle("Birthday", isOn: $hasBirthday)
            if hasBirthday {
                DatePicker(
                    "Date",
                    selection: $birthday,
                    displayedComponents: .date
                )
            }

            TextField("How We Met", text: $howWeMet)
        }
    }

    private var tagsSection: some View {
        Section("Tags") {
            TagInputView(tags: $tags)
        }
    }

    private var socialSection: some View {
        Section("Social") {
            TextField("LinkedIn URL", text: $linkedInURL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            TextField("Twitter / X Handle", text: $twitterHandle)
                .autocapitalization(.none)
            TextField("Instagram Handle", text: $instagramHandle)
                .autocapitalization(.none)
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 100)
        }
    }

    // MARK: - Data Handling

    /// Pre-populate form fields when editing an existing contact.
    private func populateFormForEditing() {
        guard let contact = contactToEdit else { return }

        firstName = contact.firstName
        lastName = contact.lastName
        phone = contact.phone
        email = contact.email
        company = contact.company
        relationshipType = contact.relationshipType
        howWeMet = contact.howWeMet
        tags = contact.tags
        linkedInURL = contact.linkedInURL
        twitterHandle = contact.twitterHandle
        instagramHandle = contact.instagramHandle
        notes = contact.notes

        if let bday = contact.birthday {
            hasBirthday = true
            birthday = bday
        }
    }

    /// Save form data to the model — either updating an existing contact
    /// or creating a new one.
    private func saveContact() {
        if let contact = contactToEdit {
            // Update existing
            contact.firstName = firstName
            contact.lastName = lastName
            contact.phone = phone
            contact.email = email
            contact.company = company
            contact.relationshipType = relationshipType
            contact.birthday = hasBirthday ? birthday : nil
            contact.howWeMet = howWeMet
            contact.tags = tags
            contact.linkedInURL = linkedInURL
            contact.twitterHandle = twitterHandle
            contact.instagramHandle = instagramHandle
            contact.notes = notes
        } else {
            // Create new
            let contact = Contact(
                firstName: firstName,
                lastName: lastName,
                company: company,
                phone: phone,
                email: email,
                birthday: hasBirthday ? birthday : nil,
                relationshipType: relationshipType,
                howWeMet: howWeMet,
                notes: notes
            )
            contact.tags = tags
            contact.linkedInURL = linkedInURL
            contact.twitterHandle = twitterHandle
            contact.instagramHandle = instagramHandle
            modelContext.insert(contact)
        }

        dismiss()
    }
}

#Preview("Add") {
    AddEditContactView()
        .modelContainer(for: Contact.self, inMemory: true)
}

#Preview("Edit") {
    let contact = Contact(firstName: "Jane", lastName: "Doe", company: "Acme")
    return AddEditContactView(contactToEdit: contact)
        .modelContainer(for: Contact.self, inMemory: true)
}
