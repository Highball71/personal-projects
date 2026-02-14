import Foundation

/// Calculates the user's learning streak — consecutive days with at least one word reviewed.
struct StreakCalculator {

    /// Computes the current streak from an array of DailyActivity records.
    /// A streak counts consecutive days ending on today (or yesterday, so the streak
    /// doesn't reset if the user hasn't studied yet today).
    /// - Parameter activities: All DailyActivity records
    /// - Returns: Number of consecutive days with activity
    static func currentStreak(from activities: [DailyActivity]) -> Int {
        guard !activities.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build a set of dates that had activity
        let activeDates = Set(activities.filter { $0.wordsReviewed > 0 }.map {
            calendar.startOfDay(for: $0.date)
        })

        // Start counting from today (or yesterday if today has no activity yet)
        var checkDate = today
        if !activeDates.contains(today) {
            // Check if yesterday had activity — if not, streak is 0
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
                return 0
            }
            if activeDates.contains(yesterday) {
                checkDate = yesterday
            } else {
                return 0
            }
        }

        // Count backwards from checkDate
        var streak = 0
        while activeDates.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }
}
