//
//  TralfazShortcuts.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import AppIntents

/// Registers all Tralfaz Siri Shortcuts so they appear in the
/// Shortcuts app and respond to "Hey Siri" voice commands.
struct TralfazShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task in \(.applicationName)",
                "Create a task in \(.applicationName)",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Add a Task",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: WhatsMyScheduleIntent(),
            phrases: [
                "What's my schedule in \(.applicationName)",
                "Show my appointments in \(.applicationName)",
                "What do I have today in \(.applicationName)"
            ],
            shortTitle: "What's My Schedule",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: AddAppointmentIntent(),
            phrases: [
                "Add an appointment in \(.applicationName)",
                "Schedule a meeting in \(.applicationName)",
                "New appointment in \(.applicationName)"
            ],
            shortTitle: "Add an Appointment",
            systemImageName: "calendar.badge.plus"
        )
    }
}
