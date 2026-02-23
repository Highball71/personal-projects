//
//  AddEditAppointmentView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// A form for creating or editing an appointment. Pass an appointment
/// to edit it, or leave nil to create a new one.
struct AddEditAppointmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var appointmentToEdit: Appointment?

    @Query(sort: \CRMProject.name) private var allProjects: [CRMProject]

    // MARK: - Form State

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var date: Date = Date()
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Date().addingTimeInterval(3600) // +1 hour
    @State private var selectedContacts: [Contact] = []
    @State private var selectedProject: CRMProject?
    @State private var notes: String = ""

    private var isEditing: Bool { appointmentToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                eventSection
                dateTimeSection
                contactsSection
                projectSection
                notesSection
            }
            .navigationTitle(isEditing ? "Edit Appointment" : "New Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAppointment() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                populateFormForEditing()
            }
        }
    }

    // MARK: - Form Sections

    private var eventSection: some View {
        Section("Event") {
            TextField("Title", text: $title)
            TextField("Location", text: $location)
        }
    }

    private var dateTimeSection: some View {
        Section("Date & Time") {
            DatePicker("Start", selection: $date)

            Toggle("End Time", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("End", selection: $endDate)
            }
        }
    }

    private var contactsSection: some View {
        Section("Contacts") {
            ContactPickerView(selectedContacts: $selectedContacts)
        }
    }

    private var projectSection: some View {
        Section("Project") {
            Picker("Project", selection: $selectedProject) {
                Text("None").tag(CRMProject?.none)
                ForEach(allProjects) { project in
                    Text(project.name).tag(CRMProject?.some(project))
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .frame(minHeight: 80)
        }
    }

    // MARK: - Data Handling

    private func populateFormForEditing() {
        guard let appointment = appointmentToEdit else { return }

        title = appointment.title
        location = appointment.location
        date = appointment.date
        selectedContacts = appointment.contactsList
        selectedProject = appointment.project
        notes = appointment.notes

        if let end = appointment.endDate {
            hasEndDate = true
            endDate = end
        }
    }

    private func saveAppointment() {
        if let appointment = appointmentToEdit {
            appointment.title = title
            appointment.location = location
            appointment.date = date
            appointment.endDate = hasEndDate ? endDate : nil
            appointment.contactsList = selectedContacts
            appointment.project = selectedProject
            appointment.notes = notes
        } else {
            let appointment = Appointment(
                title: title,
                notes: notes,
                location: location,
                date: date,
                endDate: hasEndDate ? endDate : nil,
                contacts: selectedContacts,
                project: selectedProject
            )
            modelContext.insert(appointment)
        }

        dismiss()
    }
}

#Preview {
    AddEditAppointmentView()
        .modelContainer(
            for: [Appointment.self, Contact.self, CRMProject.self],
            inMemory: true
        )
}
