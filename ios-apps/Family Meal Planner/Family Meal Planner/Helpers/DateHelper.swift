//
//  DateHelper.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// Utility functions for working with dates in the meal planner.
/// The meal plan is weekly, so we need to calculate week boundaries
/// and generate arrays of 7 consecutive days.
enum DateHelper {

    /// Returns the start of the week (Sunday or Monday, depending on locale)
    /// containing the given date.
    static func startOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Returns an array of 7 dates starting from the given date.
    static func weekDays(startingFrom startDate: Date) -> [Date] {
        let calendar = Calendar.current
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
    }

    /// Short day name: "Sun", "Mon", "Tue", etc.
    static func shortDayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    /// Day and month: "Feb 8"
    static func dayMonth(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    /// Strips the time component from a date so we can compare just the day.
    /// Without this, "Feb 8 at 10am" != "Feb 8 at midnight" even though
    /// they're the same day.
    static func stripTime(from date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
