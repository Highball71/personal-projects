import UserNotifications

/// Manages local notifications for mileage logging reminders.
/// Sends a weekday nudge if no trip has been logged by a configurable time.
enum NotificationService {
    /// Request notification permissions.
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification permission error: \(error)")
            return false
        }
    }

    /// Schedule weekday reminders at the specified hour/minute.
    /// Replaces any existing reminders.
    static func scheduleWeekdayReminders(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        // Remove old reminders before scheduling new ones
        center.removePendingNotificationRequests(withIdentifiers:
            (2...6).map { "mileage-reminder-\($0)" }
        )

        let content = UNMutableNotificationContent()
        content.title = "Log Your Mileage"
        content.body = "Don't forget to log today's trips for your tax deduction."
        content.sound = .default

        // Schedule for Monday (2) through Friday (6)
        for weekday in 2...6 {
            var dateComponents = DateComponents()
            dateComponents.weekday = weekday
            dateComponents.hour = hour
            dateComponents.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: "mileage-reminder-\(weekday)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Cancel all mileage reminders.
    static func cancelReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: (2...6).map { "mileage-reminder-\($0)" }
        )
    }

    /// Schedule an arrival notification (for when location monitoring detects arrival).
    static func sendArrivalNotification() {
        let content = UNMutableNotificationContent()
        content.title = "You've Arrived"
        content.body = "Tap to log your ending odometer reading."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "arrival-\(UUID().uuidString)",
            content: content,
            trigger: nil // Fire immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
