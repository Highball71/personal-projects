import SwiftUI
import SwiftData

/// Progress: the mastery ladder across all learned words, the streak, and the
/// activity heat map. (Rebuilt for phase 1; the old teal stat row is gone per
/// design rule #10.)
struct ProgressTabView: View {
    @Query private var wordStates: [WordState]
    @Query private var activities: [DailyActivity]

    private var totalMainWords: Int { SeedStore.mainWords.count }

    /// Count of learned words at each rung, in ladder order.
    private var rungCounts: [(stage: MasteryStage, count: Int)] {
        MasteryStage.allCases.map { stage in
            (stage, wordStates.filter { $0.mastery == stage }.count)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    StreakBadgeView(streak: StreakCalculator.currentStreak(from: activities))
                        .frame(maxWidth: .infinity)

                    masteryLadder

                    CalendarHeatMapView(activities: activities)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }

    private var masteryLadder: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Mastery ladder")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(wordStates.count) of \(totalMainWords) words met")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Top rung first: the point of the app is the climb
            ForEach(rungCounts.reversed(), id: \.stage) { rung in
                HStack(spacing: 12) {
                    Image(systemName: rung.stage.symbolName)
                        .frame(width: 28)
                        .foregroundStyle(rung.stage == .usesUnprompted ? .orange : .indigo)

                    Text(rung.stage.displayName)
                        .font(.body)

                    Spacer()

                    Text("\(rung.count)")
                        .font(.title3.bold().monospacedDigit())
                }
                .padding(.vertical, 4)
            }

            Text("The top rung only counts when you report using a word unprompted — reviews can't reach it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ProgressTabView()
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
