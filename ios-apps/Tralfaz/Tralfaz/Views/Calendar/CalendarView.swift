//
//  CalendarView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows appointments grouped by date: Today, Tomorrow, future dates,
/// and a collapsible Past section.
struct CalendarView: View {
    @Query(sort: \Appointment.date) private var appointments: [Appointment]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddAppointment = false
    @State private var searchText = ""
    @State private var showPast = false

    // MARK: - Grouped Appointments

    private var filteredAppointments: [Appointment] {
        guard !searchText.isEmpty else { return appointments }
        let query = searchText.lowercased()
        return appointments.filter { appt in
            appt.title.lowercased().contains(query)
            || appt.location.lowercased().contains(query)
            || appt.contactsList.contains { $0.displayName.lowercased().contains(query) }
        }
    }

    /// Groups appointments by calendar date, returning (label, appointments) pairs
    /// sorted chronologically. Past appointments are separated out.
    private var dateGroups: [(label: String, appointments: [Appointment])] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let upcoming = filteredAppointments.filter { $0.date >= startOfToday }

        // Group by calendar date
        let grouped = Dictionary(grouping: upcoming) { appt in
            calendar.startOfDay(for: appt.date)
        }

        return grouped.keys.sorted().map { date in
            (label: sectionLabel(for: date), appointments: grouped[date]!)
        }
    }

    private var pastAppointments: [Appointment] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return filteredAppointments
            .filter { $0.date < startOfToday }
            .sorted { $0.date > $1.date } // Most recent past first
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Upcoming grouped by date
                ForEach(dateGroups, id: \.label) { group in
                    Section(group.label) {
                        ForEach(group.appointments) { appointment in
                            NavigationLink(value: appointment) {
                                AppointmentRowView(appointment: appointment)
                            }
                        }
                        .onDelete { offsets in
                            deleteAppointments(offsets, from: group.appointments)
                        }
                    }
                }

                // Past section (collapsible)
                if !pastAppointments.isEmpty {
                    Section(isExpanded: $showPast) {
                        ForEach(pastAppointments) { appointment in
                            NavigationLink(value: appointment) {
                                AppointmentRowView(appointment: appointment)
                            }
                        }
                        .onDelete { offsets in
                            deleteAppointments(offsets, from: pastAppointments)
                        }
                    } header: {
                        Text("Past (\(pastAppointments.count))")
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Calendar")
            .navigationDestination(for: Appointment.self) { appointment in
                AppointmentDetailView(appointment: appointment)
            }
            .searchable(text: $searchText, prompt: "Search appointments")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddAppointment = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAppointment) {
                AddEditAppointmentView()
            }
            .overlay {
                if appointments.isEmpty {
                    ContentUnavailableView(
                        "No Appointments Yet",
                        systemImage: "calendar",
                        description: Text("Tap + to schedule your first appointment.")
                    )
                } else if filteredAppointments.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term.")
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    /// Returns "Today", "Tomorrow", or a formatted date string.
    private func sectionLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        }
    }

    private func deleteAppointments(_ offsets: IndexSet, from list: [Appointment]) {
        for index in offsets {
            modelContext.delete(list[index])
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: Appointment.self, inMemory: true)
}
