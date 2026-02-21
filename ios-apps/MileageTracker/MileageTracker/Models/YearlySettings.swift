import Foundation
import SwiftData

/// Per-year settings including IRS mileage rate and daily reminder preferences.
/// A new YearlySettings is created for each tax year so historical rates are preserved.
@Model
final class YearlySettings {
    var year: Int
    var irsRate: Double
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int

    init(
        year: Int = Calendar.current.component(.year, from: Date()),
        irsRate: Double = 0.725,
        reminderEnabled: Bool = true,
        reminderHour: Int = 17,
        reminderMinute: Int = 0
    ) {
        self.year = year
        self.irsRate = irsRate
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    /// Formatted reminder time for display (e.g., "5:00 PM").
    var reminderTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = reminderHour
        components.minute = reminderMinute
        guard let date = Calendar.current.date(from: components) else { return "5:00 PM" }
        return formatter.string(from: date)
    }

    /// Date object for the reminder time (today at the configured hour/minute).
    var reminderDate: Date {
        get {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = reminderHour
            components.minute = reminderMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            reminderHour = components.hour ?? 17
            reminderMinute = components.minute ?? 0
        }
    }
}
