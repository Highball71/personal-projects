//
//  AddAppointmentIntent.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import AppIntents
import SwiftData

/// Siri Shortcut: "Add an appointment in Tralfaz"
/// Creates a new Appointment with a title and date/time.
struct AddAppointmentIntent: AppIntent {
    static var title: LocalizedStringResource = "Add an Appointment"
    static var description = IntentDescription("Schedule a new appointment in Tralfaz.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    var appointmentTitle: String

    @Parameter(title: "Date and Time")
    var date: Date

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(SharedModelContainer.instance)

        let appointment = Appointment(
            title: appointmentTitle,
            date: date
        )
        context.insert(appointment)
        try context.save()

        let formatted = date.formatted(date: .abbreviated, time: .shortened)
        return .result(dialog: "Scheduled: \(appointmentTitle) on \(formatted)")
    }
}
