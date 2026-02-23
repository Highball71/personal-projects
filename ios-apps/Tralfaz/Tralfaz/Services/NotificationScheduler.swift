//
//  NotificationScheduler.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation
import UserNotifications
import SwiftData

/// Manages all local notifications for Tralfaz.
///
/// Uses an enum (no instances) because every method is a stateless utility
/// that operates on UNUserNotificationCenter and SwiftData queries.
/// This is the same pattern used in MileageTracker's NotificationService.
enum NotificationScheduler {

    // MARK: - Notification Identifiers

    // Fixed identifiers for the two repeating daily summaries
    private static let morningSummaryID = "tralfaz-morning-summary"
    private static let eveningPreviewID = "tralfaz-evening-preview"

    // Prefixes for per-item notifications (appended with a model hash)
    private static let appointmentPrefix = "tralfaz-appt-"
    private static let overdueTaskPrefix = "tralfaz-overdue-"

    // MARK: - Budget Limits
    // iOS allows max 64 pending local notifications.
    // Budget: 2 repeating + 30 appointments + 20 overdue = 52

    private static let maxAppointmentReminders = 30
    private static let maxOverdueNudges = 20

    // MARK: - Permission Request

    /// Ask the user for notification permission. Call once on first launch.
    /// Uses async/await — call from a .task modifier.
    @discardableResult
    static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    // MARK: - Full Reschedule

    /// Clears all pending notifications and rebuilds them from current
    /// SwiftData state. Call this on app foreground and after any CRUD
    /// operation on tasks or appointments.
    static func rescheduleAll(modelContext: ModelContext) {
        let center = UNUserNotificationCenter.current()

        // Wipe all pending notifications so we start fresh
        center.removeAllPendingNotificationRequests()

        // Rebuild each notification type
        scheduleMorningSummary(modelContext: modelContext)
        scheduleEveningPreview(modelContext: modelContext)
        scheduleAppointmentReminders(modelContext: modelContext)
        scheduleOverdueNudges(modelContext: modelContext)
    }

    // MARK: - Morning Summary (4:00 AM daily)

    /// Schedules a repeating notification at 4 AM with today's tasks and
    /// appointments. Content is regenerated each time rescheduleAll runs,
    /// so the summary stays as fresh as the last app open.
    private static func scheduleMorningSummary(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        // Query today's incomplete tasks with due dates
        let todayTasks = fetchTasksDue(from: startOfToday, to: startOfTomorrow,
                                       modelContext: modelContext)

        // Query today's appointments
        let todayAppointments = fetchAppointments(from: startOfToday, to: startOfTomorrow,
                                                  modelContext: modelContext)

        let content = UNMutableNotificationContent()
        content.title = "Good morning — here's your day"
        content.body = buildSummaryBody(tasks: todayTasks,
                                        appointments: todayAppointments,
                                        label: "today")
        content.sound = .default

        // Fire at 4:00 AM every day
        var trigger = DateComponents()
        trigger.hour = 4
        trigger.minute = 0

        let request = UNNotificationRequest(
            identifier: morningSummaryID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Evening Preview (7:55 PM daily)

    /// Schedules a repeating notification at 7:55 PM with tomorrow's
    /// tasks and appointments.
    private static func scheduleEveningPreview(modelContext: ModelContext) {
        let calendar = Calendar.current
        let startOfTomorrow = calendar.date(
            byAdding: .day, value: 1,
            to: calendar.startOfDay(for: Date())
        )!
        let startOfDayAfter = calendar.date(byAdding: .day, value: 1,
                                            to: startOfTomorrow)!

        let tomorrowTasks = fetchTasksDue(from: startOfTomorrow, to: startOfDayAfter,
                                          modelContext: modelContext)
        let tomorrowAppointments = fetchAppointments(from: startOfTomorrow,
                                                     to: startOfDayAfter,
                                                     modelContext: modelContext)

        let content = UNMutableNotificationContent()
        content.title = "Tomorrow's preview"
        content.body = buildSummaryBody(tasks: tomorrowTasks,
                                        appointments: tomorrowAppointments,
                                        label: "tomorrow")
        content.sound = .default

        // Fire at 7:55 PM every day
        var trigger = DateComponents()
        trigger.hour = 19
        trigger.minute = 55

        let request = UNNotificationRequest(
            identifier: eveningPreviewID,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Appointment Reminders (30 min before)

    /// Schedules a one-time notification 30 minutes before each upcoming
    /// appointment. Limited to the next 30 appointments to stay within
    /// the iOS notification budget.
    private static func scheduleAppointmentReminders(modelContext: ModelContext) {
        let now = Date()
        // Only schedule for appointments whose reminder time hasn't passed yet
        let thirtyMinFromNow = now.addingTimeInterval(30 * 60)

        var descriptor = FetchDescriptor<Appointment>(
            predicate: #Predicate<Appointment> { appointment in
                appointment.date > thirtyMinFromNow
            },
            sortBy: [SortDescriptor(\.date)]
        )
        descriptor.fetchLimit = maxAppointmentReminders

        guard let appointments = try? modelContext.fetch(descriptor) else { return }

        let calendar = Calendar.current

        for appointment in appointments {
            // Fire 30 minutes before appointment start time
            let reminderDate = appointment.date.addingTimeInterval(-30 * 60)
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            )

            let content = UNMutableNotificationContent()
            content.title = "Coming up in 30 minutes"
            content.body = appointment.title
            if !appointment.location.isEmpty {
                content.body += " at \(appointment.location)"
            }
            content.sound = .default

            // Use the persistent model ID hash for a stable, unique identifier
            let idString = appointment.persistentModelID.hashValue
            let request = UNNotificationRequest(
                identifier: "\(appointmentPrefix)\(idString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components, repeats: false
                )
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Overdue Task Nudges (9:00 AM the day after due date)

    /// Schedules a one-time nudge for each overdue incomplete task.
    /// Fires at 9 AM the day after the due date — one nudge per task,
    /// no repeated nagging. Limited to 20 tasks to stay within budget.
    private static func scheduleOverdueNudges(modelContext: ModelContext) {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)

        // Find incomplete tasks whose due date is before today (overdue)
        var descriptor = FetchDescriptor<CRMTask>(
            predicate: #Predicate<CRMTask> { task in
                task.isCompleted == false
                    && task.dueDate != nil
                    && task.dueDate! < startOfToday
            },
            sortBy: [SortDescriptor(\.dueDate)]
        )
        descriptor.fetchLimit = maxOverdueNudges

        guard let overdueTasks = try? modelContext.fetch(descriptor) else { return }

        let calendar = Calendar.current

        for task in overdueTasks {
            guard let dueDate = task.dueDate else { continue }

            // Schedule nudge at 9:00 AM the day after the due date
            let dayAfterDue = calendar.date(byAdding: .day, value: 1, to: dueDate)!
            var components = calendar.dateComponents(
                [.year, .month, .day], from: dayAfterDue
            )
            components.hour = 9
            components.minute = 0

            // Only schedule if the nudge time is still in the future
            guard let nudgeDate = calendar.date(from: components),
                  nudgeDate > now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Overdue task"
            content.body = task.title
            if task.priority == .high {
                content.body += " (high priority)"
            }
            content.sound = .default

            let idString = task.persistentModelID.hashValue
            let request = UNNotificationRequest(
                identifier: "\(overdueTaskPrefix)\(idString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components, repeats: false
                )
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    // MARK: - Data Helpers

    /// Fetch incomplete tasks whose due date falls within [startDate, endDate).
    private static func fetchTasksDue(
        from startDate: Date,
        to endDate: Date,
        modelContext: ModelContext
    ) -> [CRMTask] {
        let descriptor = FetchDescriptor<CRMTask>(
            predicate: #Predicate<CRMTask> { task in
                task.isCompleted == false
                    && task.dueDate != nil
                    && task.dueDate! >= startDate
                    && task.dueDate! < endDate
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Fetch appointments whose start date falls within [startDate, endDate).
    private static func fetchAppointments(
        from startDate: Date,
        to endDate: Date,
        modelContext: ModelContext
    ) -> [Appointment] {
        let descriptor = FetchDescriptor<Appointment>(
            predicate: #Predicate<Appointment> { appointment in
                appointment.date >= startDate
                    && appointment.date < endDate
            },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Content Builder

    /// Builds a human-readable summary string for morning/evening notifications.
    /// Example: "2 tasks due today (1 high priority). 1 appointment: Lunch with Alice at 12:30 PM."
    private static func buildSummaryBody(
        tasks: [CRMTask],
        appointments: [Appointment],
        label: String  // "today" or "tomorrow"
    ) -> String {
        // Nothing scheduled — give a friendly message
        if tasks.isEmpty && appointments.isEmpty {
            return label == "today"
                ? "No tasks or appointments today. Enjoy your day!"
                : "Nothing scheduled for tomorrow."
        }

        var parts: [String] = []

        // Task summary with high-priority callout
        if !tasks.isEmpty {
            let highCount = tasks.filter { $0.priority == .high }.count
            var taskStr = "\(tasks.count) task\(tasks.count == 1 ? "" : "s") due \(label)"
            if highCount > 0 {
                taskStr += " (\(highCount) high priority)"
            }
            parts.append(taskStr)
        }

        // Appointment summary — list up to 3 by name + time
        if !appointments.isEmpty {
            let previews = appointments.prefix(3).map { appt in
                "\(appt.title) at \(appt.date.formatted(date: .omitted, time: .shortened))"
            }
            var apptStr = "\(appointments.count) appointment\(appointments.count == 1 ? "" : "s")"
            apptStr += ": " + previews.joined(separator: ", ")
            if appointments.count > 3 {
                apptStr += ", and \(appointments.count - 3) more"
            }
            parts.append(apptStr)
        }

        return parts.joined(separator: ". ") + "."
    }
}
