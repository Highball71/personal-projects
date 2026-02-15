import SwiftUI
import SwiftData

/// The "Word Origins" tab — reveals surprising etymologies of common English words.
/// Shows session actions, progress stats, and a browsable word list.
struct DeeperTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allProgress: [EtymologyProgress]

    @State private var showingSession = false
    @State private var sessionType: EtymologySessionManager.SessionType = .mixed

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
        return allEtymologyWords.count - seenIDs.count
    }

    /// Words mastered
    private var masteredCount: Int {
        allProgress.filter { $0.status == .mastered }.count
    }

    /// Map word IDs to their progress for quick lookup
    private var progressByID: [String: EtymologyProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Mode description
                    VStack(spacing: 8) {
                        Text("Words you already know.")
                            .font(.headline)
                        Text("Origins you never guessed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Action cards
                    VStack(spacing: 16) {
                        if dueForReview > 0 {
                            actionCard(
                                title: "\(dueForReview) word\(dueForReview == 1 ? "" : "s") to review",
                                subtitle: "Revisit the origins",
                                icon: "arrow.triangle.2.circlepath",
                                color: .blue
                            ) {
                                sessionType = .reviewOnly
                                showingSession = true
                            }
                        }

                        if newWordsAvailable > 0 {
                            actionCard(
                                title: "Discover origins",
                                subtitle: "\(newWordsAvailable) word\(newWordsAvailable == 1 ? "" : "s") with hidden stories",
                                icon: "magnifyingglass",
                                color: .purple
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
                                color: .purple
                            )
                        }
                        .padding(.horizontal, 20)
                    }

                    // Word list
                    VStack(alignment: .leading, spacing: 12) {
                        Text("All Words")
                            .font(.headline)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(allEtymologyWords) { word in
                                NavigationLink {
                                    EtymologyDetailView(word: word, progress: progressByID[word.id])
                                } label: {
                                    etymologyRow(word)
                                }
                                .buttonStyle(.plain)

                                if word.id != allEtymologyWords.last?.id {
                                    Divider()
                                        .padding(.leading, 20)
                                }
                            }
                        }
                        .background(.background, in: .rect(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 40)
                }
            }
            .navigationTitle("Word Origins")
            .background(Color(.systemGroupedBackground))
            .fullScreenCover(isPresented: $showingSession) {
                EtymologySessionView(sessionType: sessionType)
            }
        }
    }

    // MARK: - Etymology Row

    private func etymologyRow(_ word: EtymologyWord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(word.word)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(word.originLanguage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                }

                Text(word.literalMeaning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            statusIcon(for: word)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func statusIcon(for word: EtymologyWord) -> some View {
        Group {
            if let progress = progressByID[word.id] {
                if progress.status == .mastered {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.orange)
                }
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(.purple)
            }
        }
        .font(.subheadline)
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

            Text("You've explored all the origins and none are due for review. Check back later!")
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

// MARK: - Etymology Detail View

/// Full detail view for a single etymology word.
struct EtymologyDetailView: View {
    let word: EtymologyWord
    let progress: EtymologyProgress?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(word.word)
                        .font(.largeTitle.bold())

                    Text(word.originLanguage)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5), in: .capsule)

                    if let progress {
                        Text(progress.status == .mastered ? "Mastered" : "Learning")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(progress.status == .mastered ? .green : .orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                (progress.status == .mastered ? Color.green : Color.orange).opacity(0.12),
                                in: .capsule
                            )
                    }
                }

                Divider()

                // Casual intro
                VStack(alignment: .leading, spacing: 6) {
                    Text("What you think it means")
                        .font(.headline)
                    Text(word.casualIntro)
                        .font(.body)
                        .lineSpacing(4)
                        .foregroundStyle(.secondary)
                }

                // Etymology
                VStack(alignment: .leading, spacing: 10) {
                    Text("The real origin")
                        .font(.headline)

                    HStack(spacing: 8) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(word.breakdown)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tint)
                    }

                    Text("= \"\(word.literalMeaning)\"")
                        .font(.title3.bold())

                    Text(word.originStory)
                        .font(.body)
                        .lineSpacing(4)
                }

                // Stats (if user has progress)
                if let progress {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Learning Stats")
                            .font(.headline)

                        statsRow(label: "First seen", value: progress.dateFirstSeen.formatted(date: .abbreviated, time: .omitted))
                        statsRow(label: "Last reviewed", value: progress.lastReviewDate.formatted(date: .abbreviated, time: .omitted))
                        statsRow(label: "Reviews", value: "\(progress.repetitions)")
                        statsRow(label: "Next review", value: progress.nextReviewDate.formatted(date: .abbreviated, time: .omitted))
                        statsRow(label: "Interval", value: "\(progress.interval) day\(progress.interval == 1 ? "" : "s")")
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statsRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    DeeperTabView()
        .modelContainer(for: [EtymologyProgress.self, DailyActivity.self], inMemory: true)
}
