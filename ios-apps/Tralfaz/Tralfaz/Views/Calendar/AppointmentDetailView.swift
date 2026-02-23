//
//  AppointmentDetailView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Read-only detail view for an appointment.
struct AppointmentDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let appointment: Appointment

    @State private var showingEditSheet = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            eventInfoSection
            contactsSection
            projectSection
            notesSection
            deleteSection
        }
        .navigationTitle(appointment.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            AddEditAppointmentView(appointmentToEdit: appointment)
        }
        .alert("Delete this appointment?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(appointment)
                NotificationScheduler.rescheduleAll(modelContext: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }

    // MARK: - Sections

    private var eventInfoSection: some View {
        Section("Event Info") {
            LabeledContent("Date", value: appointment.date.formatted(date: .long, time: .shortened))

            if let endDate = appointment.endDate {
                LabeledContent("End", value: endDate.formatted(date: .long, time: .shortened))
            }

            if !appointment.location.isEmpty {
                LabeledContent("Location", value: appointment.location)
            }
        }
    }

    @ViewBuilder
    private var contactsSection: some View {
        if !appointment.contactsList.isEmpty {
            Section("Contacts") {
                ForEach(appointment.contactsList) { contact in
                    Text(contact.displayName)
                }
            }
        }
    }

    @ViewBuilder
    private var projectSection: some View {
        if let project = appointment.project {
            Section("Project") {
                LabeledContent("Project", value: project.name)
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if !appointment.notes.isEmpty {
            Section("Notes") {
                Text(appointment.notes)
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button("Delete Appointment", role: .destructive) {
                showingDeleteConfirmation = true
            }
        }
    }
}
