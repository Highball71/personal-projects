import SwiftUI

/// The reveal card: the word, how to say it, its one precise job, and the
/// neighbours it must be distinguished from. Used at the lesson reveal moment
/// and in the collection detail.
struct WordCardView: View {
    let word: SeedWord
    var onSpeak: ((String) -> Void)? = nil

    /// Staged disclosure for the lesson: the definition and neighbours appear
    /// as they are spoken (phase-2 decision 1). Callers outside the lesson
    /// leave both true and get the whole card at once.
    var showDefinition: Bool = true
    var showNeighbors: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The word itself, with pronunciation
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(word.word)
                        .font(.system(.largeTitle, design: .serif).bold())
                    if let onSpeak {
                        Button {
                            onSpeak(word.word)
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.indigo)
                        .accessibilityLabel("Hear the word")
                    }
                }
                HStack(spacing: 8) {
                    Text(word.ipa)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                    Text(word.partOfSpeech)
                        .font(.caption.smallCaps())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5), in: .capsule)
                }
            }

            if showDefinition {
                Text(word.definition)
                    .font(.title3)
                    .transition(.opacity)
            }

            // The distinctions — this is where precision lives
            if showNeighbors {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Not to be confused with")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(word.neighbors, id: \.word) { neighbor in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(neighbor.word)
                                .font(.body.weight(.semibold))
                                .italic()
                            Text(neighbor.distinction)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ScrollView {
        WordCardView(word: SeedStore.mainWords.first!, onSpeak: { _ in })
            .padding()
    }
}
