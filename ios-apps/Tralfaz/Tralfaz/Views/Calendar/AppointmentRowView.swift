//
//  AppointmentRowView.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import SwiftUI

/// A single row in the appointments list showing title, time range,
/// location, and how many contacts are involved.
struct AppointmentRowView: View {
    let appointment: Appointment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(appointment.title)
                    .font(.body)

                Text(timeRangeText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !appointment.location.isEmpty {
                    Label(appointment.location, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Contact count badge
            let count = appointment.contactsList.count
            if count > 0 {
                Label("\(count)", systemImage: "person.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timeRangeText: String {
        let start = appointment.date.formatted(date: .omitted, time: .shortened)
        if let end = appointment.endDate {
            let endStr = end.formatted(date: .omitted, time: .shortened)
            return "\(start) – \(endStr)"
        }
        return start
    }
}
