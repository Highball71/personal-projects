//
//  WhatsMyScheduleIntent.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import AppIntents
import SwiftData

/// Siri Shortcut: "What's my schedule in Tralfaz"
/// Reads back today's appointments as a spoken summary.
struct WhatsMyScheduleIntent: AppIntent {
    static var title: LocalizedStringResource = "What's My Schedule"
    static var description = IntentDescription("Read back today's appointments from Tralfaz.")

    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.instance)

        // Fetch today's appointments
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let descriptor = FetchDescriptor<Appointment>(
            predicate: #Predicate { appointment in
                appointment.date >= startOfDay && appointment.date < endOfDay
            },
            sortBy: [SortDescriptor(\.date)]
        )

        let appointments = try context.fetch(descriptor)

        if appointments.isEmpty {
            return .result(dialog: "You have no appointments today.")
        }

        // Build a spoken summary
        let count = appointments.count
        let noun = count == 1 ? "appointment" : "appointments"
        var summary = "You have \(count) \(noun) today. "

        let items = appointments.map { appointment in
            let time = appointment.date.formatted(date: .omitted, time: .shortened)
            return "\(appointment.title) at \(time)"
        }

        // Join with commas and "and" before the last item
        if items.count == 1 {
            summary += items[0] + "."
        } else {
            summary += items.dropLast().joined(separator: ", ")
            summary += ", and \(items.last!)."
        }

        return .result(dialog: "\(summary)")
    }
}
