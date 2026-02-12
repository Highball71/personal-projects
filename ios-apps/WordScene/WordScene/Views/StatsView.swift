import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \WordProgress.dateEncountered, order: .reverse)
    private var progressEntries: [WordProgress]

    /// Words the user tapped "Knew it" for
    private var masteredEntries: [WordProgress] {
        progressEntries.filter(\.knewIt)
    }

    /// Words the user tapped "New to me" for (and haven't since mastered)
    private var learningEntries: [WordProgress] {
        progressEntries.filter { !$0.knewIt }
    }

    /// Look up the full VocabularyWord for a progress entry
    private func vocabularyWord(for entry: WordProgress) -> VocabularyWord? {
        allWords.first { $0.id == entry.wordID }
    }

    var body: some View {
        NavigationStack {
            List {
                // Stats summary section
                Section {
                    statsRow(
                        label: "Total Words",
                        value: "\(allWords.count)",
                        icon: "book",
                        color: .blue
                    )
                    statsRow(
                        label: "Words Seen",
                        value: "\(progressEntries.count)",
                        icon: "eye",
                        color: .purple
                    )
                    statsRow(
                        label: "Mastered",
                        value: "\(masteredEntries.count)",
                        icon: "checkmark.seal",
                        color: .green
                    )
                    statsRow(
                        label: "Learning",
                        value: "\(learningEntries.count)",
                        icon: "lightbulb",
                        color: .orange
                    )
                }

                // Progress bar section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Mastery Progress")
                            .font(.headline)

                        ProgressView(
                            value: Double(masteredEntries.count),
                            total: Double(allWords.count)
                        )
                        .tint(.green)

                        Text("\(masteredEntries.count) of \(allWords.count) words mastered")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Mastered words list
                if !masteredEntries.isEmpty {
                    Section("Mastered Words") {
                        ForEach(masteredEntries, id: \.wordID) { entry in
                            if let word = vocabularyWord(for: entry) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(word.word)
                                            .font(.headline)
                                        Text(word.partOfSpeech)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                    Text(word.definition)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                // Learning words list
                if !learningEntries.isEmpty {
                    Section("Still Learning") {
                        ForEach(learningEntries, id: \.wordID) { entry in
                            if let word = vocabularyWord(for: entry) {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(word.word)
                                            .font(.headline)
                                        Text(word.partOfSpeech)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .italic()
                                    }
                                    Text(word.definition)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Progress")
            .overlay {
                if progressEntries.isEmpty {
                    ContentUnavailableView(
                        "No Words Yet",
                        systemImage: "text.book.closed",
                        description: Text("Start reading scenarios to build your vocabulary!")
                    )
                }
            }
        }
    }

    // MARK: - Stats Row

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
}

#Preview {
    StatsView()
        .modelContainer(for: WordProgress.self, inMemory: true)
}
