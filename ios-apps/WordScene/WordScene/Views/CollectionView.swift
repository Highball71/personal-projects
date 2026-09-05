import SwiftUI
import SwiftData

/// The collection: every domain ladder, broadest to narrowest, with mastery
/// shown per word. Unlearned words stay locked — opening a word's card before
/// its lesson would spoil the scene-first reveal (decision #1), so browsing
/// shows the shape of each ladder without leaking definitions.
struct CollectionView: View {
    @Query private var wordStates: [WordState]

    private var statesByID: [String: WordState] {
        Dictionary(uniqueKeysWithValues: wordStates.map { ($0.wordID, $0) })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(SeedStore.ladderDomains, id: \.self) { domain in
                    Section {
                        ForEach(SeedStore.ladder(for: domain)) { word in
                            ladderRow(word)
                        }
                    } header: {
                        domainHeader(domain)
                    }
                }
            }
            .navigationTitle("Collection")
        }
    }

    private func domainHeader(_ domain: String) -> some View {
        let ladder = SeedStore.ladder(for: domain)
        let learned = ladder.filter { statesByID[$0.id] != nil }.count
        return HStack {
            Text(ladder.first?.domainDisplayName ?? domain)
            Spacer()
            Text("\(learned)/\(ladder.count)")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func ladderRow(_ word: SeedWord) -> some View {
        if let state = statesByID[word.id] {
            NavigationLink {
                WordDetailView(word: word, state: state)
            } label: {
                learnedRow(word, state: state)
            }
        } else {
            lockedRow(word)
        }
    }

    private func learnedRow(_ word: SeedWord, state: WordState) -> some View {
        HStack(spacing: 12) {
            rankBadge(word.ladderRank)
            VStack(alignment: .leading, spacing: 2) {
                Text(word.word)
                    .font(.body.weight(.medium))
                Text(word.definition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Label(state.mastery.displayName, systemImage: state.mastery.symbolName)
                .font(.caption)
                .labelStyle(.titleAndIcon)
                .foregroundStyle(state.mastery == .usesUnprompted ? .orange : .secondary)
        }
    }

    /// Locked rows show only the rank slot — not even the word. The first
    /// meeting should be the spoken scene, not a list entry.
    private func lockedRow(_ word: SeedWord) -> some View {
        HStack(spacing: 12) {
            rankBadge(word.ladderRank)
            Text("Not yet learned")
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer()
            Image(systemName: "lock")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func rankBadge(_ rank: Int) -> some View {
        Text("\(rank)")
            .font(.caption.bold().monospacedDigit())
            .frame(width: 24, height: 24)
            .background(Color(.systemGray5), in: .circle)
            .foregroundStyle(.secondary)
    }
}

/// Full card for a learned word, plus its original scene and mastery info.
struct WordDetailView: View {
    let word: SeedWord
    let state: WordState

    @State private var speech = SpeechService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WordCardView(word: word) { text in
                    speech.speak(text, slowly: true)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("The scene")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(word.systemScene)
                        .font(.subheadline)
                        .lineSpacing(3)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                LabeledContent("Mastery") {
                    Label(state.mastery.displayName, systemImage: state.mastery.symbolName)
                }
                LabeledContent("Next review") {
                    Text(state.dueDate, style: .date)
                }
            }
            .padding()
        }
        .navigationTitle(word.word)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { speech.stop() }
    }
}

#Preview {
    CollectionView()
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
