import SwiftUI
import SwiftData

/// Progress tab — shows mastered/learning/new counts with visual progress and a calendar heat map.
struct ProgressTabView: View {
    @Query(sort: \WordProgress.lastReviewDate, order: .reverse)
    private var allProgress: [WordProgress]

    @Query(sort: \DailyActivity.date, order: .reverse)
    private var activities: [DailyActivity]

    private var masteredCount: Int {
        allProgress.filter { $0.status == .mastered }.count
    }

    private var learningCount: Int {
        allProgress.filter { $0.status == .learning }.count
    }

    private var newCount: Int {
        allWords.count - allProgress.count
    }

    private var totalReviewed: Int {
        activities.reduce(0) { $0 + $1.wordsReviewed }
    }

    var body: some View {
        NavigationStack {
            List {
                // Overview section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Mastery Progress")
                            .font(.headline)

                        // Stacked progress bar
                        GeometryReader { geo in
                            let width = geo.size.width
                            let total = Double(allWords.count)
                            let masteredWidth = total > 0 ? (Double(masteredCount) / total) * width : 0
                            let learningWidth = total > 0 ? (Double(learningCount) / total) * width : 0

                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(.green)
                                    .frame(width: masteredWidth)
                                Rectangle()
                                    .fill(.orange)
                                    .frame(width: learningWidth)
                                Rectangle()
                                    .fill(Color(.systemGray4))
                            }
                            .frame(height: 8)
                            .clipShape(.rect(cornerRadius: 4))
                        }
                        .frame(height: 8)

                        // Legend
                        HStack(spacing: 16) {
                            legendItem(color: .green, label: "Mastered", count: masteredCount)
                            legendItem(color: .orange, label: "Learning", count: learningCount)
                            legendItem(color: Color(.systemGray4), label: "New", count: newCount)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Stats
                Section("Statistics") {
                    statsRow(label: "Total words", value: "\(allWords.count)", icon: "book", color: .blue)
                    statsRow(label: "Words encountered", value: "\(allProgress.count)", icon: "eye", color: .purple)
                    statsRow(label: "Total reviews", value: "\(totalReviewed)", icon: "arrow.triangle.2.circlepath", color: .teal)
                    statsRow(label: "Streak", value: "\(StreakCalculator.currentStreak(from: activities)) days", icon: "flame.fill", color: .orange)
                }

                // Calendar heat map
                Section {
                    CalendarHeatMapView(activities: activities)
                        .padding(.vertical, 4)
                }

                // Recently reviewed
                if !allProgress.isEmpty {
                    Section("Recently Reviewed") {
                        ForEach(allProgress.prefix(10), id: \.wordID) { progress in
                            if let word = wordsByID[progress.wordID] {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(word.word)
                                            .font(.headline)
                                        Text(word.definition)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    statusBadge(for: progress.status)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Progress")
            .overlay {
                if allProgress.isEmpty {
                    ContentUnavailableView(
                        "No Progress Yet",
                        systemImage: "chart.bar",
                        description: Text("Start learning words to track your progress!")
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) (\(count))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statsRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    private func statusBadge(for status: WordStatus) -> some View {
        Text(status == .mastered ? "Mastered" : "Learning")
            .font(.caption2.weight(.medium))
            .foregroundStyle(status == .mastered ? .green : .orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                (status == .mastered ? Color.green : Color.orange).opacity(0.12),
                in: .capsule
            )
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(for: [WordProgress.self, DailyActivity.self], inMemory: true)
}
