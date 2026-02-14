import SwiftUI
import SwiftData

/// Home tab — shows review count, learn button, streak counter, and quick stats.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [WordProgress]
    @Query private var activities: [DailyActivity]

    @State private var showingSession = false
    @State private var sessionType: SessionManager.SessionType = .mixed

    /// Words due for review today
    private var dueForReview: Int {
        let tomorrow = Calendar.current.date(
            byAdding: .day, value: 1,
            to: Calendar.current.startOfDay(for: Date())
        )!
        return allProgress.filter { $0.nextReviewDate < tomorrow }.count
    }

    /// Words never seen
    private var newWordsAvailable: Int {
        let seenIDs = Set(allProgress.map(\.wordID))
        return allWords.count - seenIDs.count
    }

    /// Current streak
    private var streak: Int {
        StreakCalculator.currentStreak(from: activities)
    }

    /// Words mastered
    private var masteredCount: Int {
        allProgress.filter { $0.status == .mastered }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Streak display
                    StreakBadgeView(streak: streak)
                        .padding(.top, 8)

                    // Main action cards
                    VStack(spacing: 16) {
                        if dueForReview > 0 {
                            actionCard(
                                title: "\(dueForReview) word\(dueForReview == 1 ? "" : "s") to review",
                                subtitle: "Keep your memory fresh",
                                icon: "arrow.triangle.2.circlepath",
                                color: .blue
                            ) {
                                sessionType = .reviewOnly
                                showingSession = true
                            }
                        }

                        if newWordsAvailable > 0 {
                            actionCard(
                                title: "Learn new words",
                                subtitle: "\(newWordsAvailable) words waiting to be discovered",
                                icon: "sparkles",
                                color: .green
                            ) {
                                sessionType = .mixed
                                showingSession = true
                            }
                        }

                        if dueForReview == 0 && newWordsAvailable == 0 {
                            allDoneCard
                        }
                    }
                    .padding(.horizontal, 20)

                    // Quick stats
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your Progress")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        HStack(spacing: 16) {
                            statPill(
                                label: "Mastered",
                                value: "\(masteredCount)",
                                icon: "checkmark.seal.fill",
                                color: .green
                            )
                            statPill(
                                label: "Learning",
                                value: "\(allProgress.count - masteredCount)",
                                icon: "brain.head.profile",
                                color: .orange
                            )
                            statPill(
                                label: "New",
                                value: "\(newWordsAvailable)",
                                icon: "plus.circle.fill",
                                color: .blue
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("WordScene")
            .background(Color(.systemGroupedBackground))
            .fullScreenCover(isPresented: $showingSession) {
                SessionView(sessionType: sessionType)
            }
        }
    }

    // MARK: - Action Card

    private func actionCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(color)
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.12), in: .circle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(.background, in: .rect(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - All Done Card

    private var allDoneCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "party.popper.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("All caught up!")
                .font(.title3.bold())

            Text("You've seen all the words and none are due for review. Check back later!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.background, in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Stat Pill

    private func statPill(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background, in: .rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.03), radius: 4, y: 1)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [WordProgress.self, DailyActivity.self], inMemory: true)
}
