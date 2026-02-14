import SwiftUI

/// A GitHub-style calendar heat map showing 90 days of learning activity.
/// Color intensity corresponds to the number of words reviewed each day.
struct CalendarHeatMapView: View {
    let activities: [DailyActivity]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private let dayCount = 91 // 13 weeks

    /// Build a lookup from date -> wordsReviewed count
    private var activityByDate: [Date: Int] {
        let calendar = Calendar.current
        return Dictionary(
            activities.map { (calendar.startOfDay(for: $0.date), $0.wordsReviewed) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// The maximum words reviewed in a single day (for scaling intensity)
    private var maxReviewed: Int {
        max(activities.map(\.wordsReviewed).max() ?? 1, 1)
    }

    /// Generate the last 91 days, aligned to start on a Sunday
    private var dateGrid: [Date?] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Find the start date (91 days ago, aligned to Sunday)
        guard let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) else {
            return []
        }

        // Pad the beginning to align with Sunday (weekday 1)
        let startWeekday = calendar.component(.weekday, from: startDate)
        let padding = startWeekday - 1 // Sunday = 1, so 0 padding if already Sunday

        var grid: [Date?] = Array(repeating: nil, count: padding)

        for i in 0..<dayCount {
            if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                grid.append(date)
            }
        }

        return grid
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day-of-week labels
            HStack(spacing: 0) {
                // Month labels across the top
                Text("Activity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Last 90 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // The grid
            LazyVGrid(columns: columns, spacing: 3) {
                ForEach(Array(dateGrid.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let count = activityByDate[date] ?? 0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(cellColor(for: count))
                            .frame(height: 14)
                            .help(cellTooltip(date: date, count: count))
                    } else {
                        // Empty padding cell
                        Color.clear
                            .frame(height: 14)
                    }
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(intensityColor(level: level))
                        .frame(width: 12, height: 12)
                }

                Text("More")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Color Logic

    private func cellColor(for count: Int) -> Color {
        if count == 0 {
            return Color(.systemGray5)
        }
        let ratio = Double(count) / Double(maxReviewed)
        let level: Int
        if ratio < 0.25 { level = 1 }
        else if ratio < 0.5 { level = 2 }
        else if ratio < 0.75 { level = 3 }
        else { level = 4 }
        return intensityColor(level: level)
    }

    private func intensityColor(level: Int) -> Color {
        switch level {
        case 0: return Color(.systemGray5)
        case 1: return .green.opacity(0.3)
        case 2: return .green.opacity(0.5)
        case 3: return .green.opacity(0.7)
        default: return .green.opacity(0.9)
        }
    }

    private func cellTooltip(date: Date, count: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)
        if count == 0 {
            return "\(dateStr): No activity"
        }
        return "\(dateStr): \(count) word\(count == 1 ? "" : "s")"
    }
}

#Preview {
    CalendarHeatMapView(activities: [])
        .padding()
}
