import SwiftUI
import SwiftData

/// Full detail view for a single vocabulary word.
/// Shows pronunciation, definition, etymology, all scenarios, and SM-2 stats if the user has progress.
struct WordDetailSheet: View {
    let word: VocabularyWord
    let progress: WordProgress?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(word.word)
                            .font(.largeTitle.bold())

                        Text(word.partOfSpeech)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .italic()
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(word.pronunciation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    if let progress {
                        statusBadge(for: progress.status)
                    }
                }

                Divider()

                // Definition
                VStack(alignment: .leading, spacing: 6) {
                    Text("Definition")
                        .font(.headline)
                    Text(word.definition)
                        .font(.body)
                        .lineSpacing(4)
                }

                // Etymology
                VStack(alignment: .leading, spacing: 6) {
                    Text("Etymology")
                        .font(.headline)
                    Text(word.etymology)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }

                Divider()

                // Scenarios
                VStack(alignment: .leading, spacing: 12) {
                    Text("Scenarios")
                        .font(.headline)

                    ForEach(Array(word.scenarios.enumerated()), id: \.offset) { index, scenario in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scenario \(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(scenario)
                                .font(.body)
                                .lineSpacing(4)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6), in: .rect(cornerRadius: 10))
                    }
                }

                // SM-2 Stats (if user has progress)
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
                        statsRow(label: "Ease factor", value: String(format: "%.2f", progress.easeFactor))
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statusBadge(for status: WordStatus) -> some View {
        Text(status == .mastered ? "Mastered" : "Learning")
            .font(.caption.weight(.semibold))
            .foregroundStyle(status == .mastered ? .green : .orange)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                (status == .mastered ? Color.green : Color.orange).opacity(0.12),
                in: .capsule
            )
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
    NavigationStack {
        WordDetailSheet(word: allWords[0], progress: nil)
    }
}
