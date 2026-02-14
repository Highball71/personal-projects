import SwiftUI
import SwiftData

/// Browse all 100 words with search and filter by status (mastered/learning/new).
struct WordListView: View {
    @Query private var allProgress: [WordProgress]

    @State private var searchText = ""
    @State private var selectedFilter: WordStatusFilter = .all

    /// Map word IDs to their progress for quick lookup
    private var progressByID: [String: WordProgress] {
        Dictionary(uniqueKeysWithValues: allProgress.map { ($0.wordID, $0) })
    }

    /// Get the status of a word
    private func status(for word: VocabularyWord) -> WordStatus {
        guard let progress = progressByID[word.id] else { return .new }
        return progress.status
    }

    /// Filtered and searched words
    private var filteredWords: [VocabularyWord] {
        allWords.filter { word in
            // Filter by status
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .mastered: matchesFilter = status(for: word) == .mastered
            case .learning: matchesFilter = status(for: word) == .learning
            case .new: matchesFilter = status(for: word) == .new
            }

            // Filter by search text
            let matchesSearch = searchText.isEmpty ||
                word.word.localizedCaseInsensitiveContains(searchText) ||
                word.definition.localizedCaseInsensitiveContains(searchText)

            return matchesFilter && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List {
                // Filter picker
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(WordStatusFilter.allCases) { filter in
                            Text(filter.label).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                // Word list
                Section {
                    ForEach(filteredWords) { word in
                        NavigationLink {
                            WordDetailSheet(word: word, progress: progressByID[word.id])
                        } label: {
                            wordRow(word)
                        }
                    }
                }
            }
            .navigationTitle("Words")
            .searchable(text: $searchText, prompt: "Search words...")
            .overlay {
                if filteredWords.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else if filteredWords.isEmpty {
                    ContentUnavailableView(
                        "No Words",
                        systemImage: "text.book.closed",
                        description: Text("No words match the selected filter.")
                    )
                }
            }
        }
    }

    // MARK: - Word Row

    private func wordRow(_ word: VocabularyWord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
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

            Spacer()

            statusIcon(for: status(for: word))
        }
        .padding(.vertical, 2)
    }

    private func statusIcon(for status: WordStatus) -> some View {
        Group {
            switch status {
            case .mastered:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .learning:
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.orange)
            case .new:
                Image(systemName: "plus.circle")
                    .foregroundStyle(.blue)
            }
        }
        .font(.subheadline)
    }
}

/// Filter options for the word list
enum WordStatusFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case learning
    case mastered

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "All"
        case .new: return "New"
        case .learning: return "Learning"
        case .mastered: return "Mastered"
        }
    }
}

#Preview {
    WordListView()
        .modelContainer(for: [WordProgress.self, DailyActivity.self], inMemory: true)
}
