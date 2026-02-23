//
//  CalendarView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI
import SwiftData

/// Shows upcoming appointments.
struct CalendarView: View {
    @Query(sort: \Appointment.date) private var appointments: [Appointment]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List {
                ForEach(appointments) { appointment in
                    Text(appointment.title)
                }
            }
            .navigationTitle("Calendar")
            .overlay {
                if appointments.isEmpty {
                    ContentUnavailableView(
                        "No Appointments Yet",
                        systemImage: "calendar",
                        description: Text("Tap + to schedule your first appointment.")
                    )
                }
            }
        }
    }
}

#Preview {
    CalendarView()
        .modelContainer(for: Appointment.self, inMemory: true)
}
