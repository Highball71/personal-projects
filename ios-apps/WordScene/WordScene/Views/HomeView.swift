import SwiftUI
import SwiftData

/// Home: pick a precision tier, learn new words, review what's due.
/// The tier switch is the level switch reimagined (decision, 2026-09-05):
/// Broad / Narrow / Needle band words by how narrow their job is — never
/// by how common they are.
struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var wordStates: [WordState]
    @Query private var activities: [DailyActivity]
    @Query private var userScenes: [UserScene]
    @Query private var reviewLogs: [ReviewLog]

    /// Persisted so the app opens where the user left off
    @AppStorage("selectedTier") private var selectedTierRaw = PrecisionTier.broad.rawValue

    // Wrapped in Identifiable payloads because fullScreenCover(item:) needs one
    @State private var lessonPayload: LessonPayload?
    @State private var reviewPayload: ReviewPayload?

    private struct LessonPayload: Identifiable {
        let id = UUID()
        let words: [SeedWord]
    }

    private struct ReviewPayload: Identifiable {
        let id = UUID()
        let questions: [ReviewBuilder.Question]
    }

    private var selectedTier: PrecisionTier {
        PrecisionTier(rawValue: selectedTierRaw) ?? .broad
    }

    private var learnedWordIDs: Set<String> {
        Set(wordStates.map(\.wordID))
    }

    private var dueWordIDs: [String] {
        wordStates.filter { $0.isDue() }.map(\.wordID)
    }

    private var remainingInTier: Int {
        LessonBuilder.remainingCount(tier: selectedTier, learnedWordIDs: learnedWordIDs)
    }

    /// Words sitting at the Produces rung, waiting for real-world use — the
    /// one promotion the app can't grant (hard constraint: self-report only).
    private var wildCandidates: [WordState] {
        wordStates.filter { $0.mastery == .producesOnPrompt }
    }

    /// Gentle weekly cadence: only nudge if nothing was reported in 7 days.
    private var shouldNudgeWildUse: Bool {
        guard !wildCandidates.isEmpty else { return false }
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentReport = reviewLogs.contains {
            $0.activity == ReviewLog.Activity.unpromptedUse.rawValue && $0.date > weekAgo
        }
        return !recentReport
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    StreakBadgeView(streak: StreakCalculator.currentStreak(from: activities))
                        .frame(maxWidth: .infinity)

                    tierPicker

                    learnCard

                    reviewCard

                    if shouldNudgeWildUse {
                        wildUseNudge
                    }
                }
                .padding()
            }
            .navigationTitle("WordScene")
        }
        .fullScreenCover(item: $lessonPayload) { payload in
            LessonView(words: payload.words)
        }
        .fullScreenCover(item: $reviewPayload) { payload in
            ReviewView(questions: payload.questions)
        }
    }

    private var tierPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Precision", selection: $selectedTierRaw) {
                ForEach(PrecisionTier.allCases) { tier in
                    Text(tier.displayName).tag(tier.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text(selectedTier.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var learnCard: some View {
        Button {
            let words = LessonBuilder.nextWords(tier: selectedTier, learnedWordIDs: learnedWordIDs)
            if !words.isEmpty { lessonPayload = LessonPayload(words: words) }
        } label: {
            actionCard(
                title: "Learn new words",
                subtitle: remainingInTier > 0
                    ? "\(remainingInTier) waiting in \(selectedTier.displayName)"
                    : "\(selectedTier.displayName) tier complete — try another",
                symbol: "headphones",
                tint: .indigo,
                enabled: remainingInTier > 0
            )
        }
        .buttonStyle(.plain)
        .disabled(remainingInTier == 0)
    }

    private var reviewCard: some View {
        Button {
            let questions = ReviewBuilder.buildSession(.init(
                dueWordIDs: dueWordIDs,
                learnedWordIDs: learnedWordIDs,
                masteryByID: Dictionary(uniqueKeysWithValues: wordStates.map { ($0.wordID, $0.mastery) }),
                userScenesByWordID: Dictionary(grouping: userScenes.filter { $0.wordID != nil }, by: { $0.wordID! })
                    .mapValues { $0.map(\.text) }
            ))
            if !questions.isEmpty { reviewPayload = ReviewPayload(questions: questions) }
        } label: {
            actionCard(
                title: "Review",
                subtitle: dueWordIDs.isEmpty
                    ? "Nothing due — scenes return on their own schedule"
                    : "\(dueWordIDs.count) word\(dueWordIDs.count == 1 ? "" : "s") due",
                symbol: "arrow.triangle.2.circlepath",
                tint: .orange,
                enabled: !dueWordIDs.isEmpty
            )
        }
        .buttonStyle(.plain)
        .disabled(dueWordIDs.isEmpty)
    }

    /// The top rung waits on life, not the app: a quiet reminder that some
    /// words are ready to be used out loud. Marking it lives on each word's
    /// page in the Collection.
    private var wildUseNudge: some View {
        HStack(spacing: 16) {
            Image(systemName: "star")
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(wildCandidates.count == 1
                     ? "1 word is ready for the wild"
                     : "\(wildCandidates.count) words are ready for the wild")
                    .font(.headline)
                Text("Drop one into a real conversation this week, then mark it on its page in the Collection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionCard(title: String, subtitle: String, symbol: String, tint: Color, enabled: Bool) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(enabled ? tint : .secondary)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .opacity(enabled ? 1 : 0.6)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
