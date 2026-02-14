import SwiftUI

/// A single card in a learning session.
/// Shows the scenario with the vocabulary word highlighted. User taps to reveal the definition,
/// then rates their knowledge.
struct SessionCardView: View {
    let card: SessionManager.SessionCard
    let onRate: (SM2Engine.Quality) -> Void

    @State private var showingDefinition = false
    @State private var hasRated = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // New/Review badge
                    HStack {
                        Text(card.isReview ? "Review" : "New Word")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(card.isReview ? .blue : .green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(
                                (card.isReview ? Color.blue : Color.green).opacity(0.12),
                                in: .capsule
                            )
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                    // The scenario text with the vocabulary word highlighted
                    scenarioText
                        .padding(.horizontal, 24)

                    if !showingDefinition && !hasRated {
                        Text("Tap the highlighted word to reveal its meaning")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }

                    // Definition reveal section
                    if showingDefinition {
                        definitionCard
                            .padding(.horizontal, 24)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }

                    Spacer(minLength: 20)
                }
            }

            // Rating buttons at the bottom
            if showingDefinition && !hasRated {
                ratingButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if hasRated {
                // Brief confirmation, parent view handles advancing
                Text("Got it!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Scenario Text

    /// Builds the scenario text with the vocabulary word as a tappable highlight.
    @ViewBuilder
    private var scenarioText: some View {
        let scenario = card.word.scenarios[card.scenarioIndex]
        let target = card.word.word.lowercased()

        if let range = scenario.lowercased().range(of: target) {
            let before = String(scenario[scenario.startIndex..<range.lowerBound])
            let matched = String(scenario[range])
            let after = String(scenario[range.upperBound..<scenario.endIndex])

            (
                Text(before)
                    .foregroundStyle(.primary)
                +
                Text(matched)
                    .bold()
                    .foregroundStyle(.tint)
                    .underline()
                +
                Text(after)
                    .foregroundStyle(.primary)
            )
            .font(.title3)
            .lineSpacing(6)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onTapGesture {
                guard !showingDefinition else { return }
                withAnimation(.spring(duration: 0.4)) {
                    showingDefinition = true
                }
            }
        } else {
            // Fallback if the word isn't found in the scenario
            Text(scenario)
                .font(.title3)
                .lineSpacing(6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Definition Card

    private var definitionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Word + part of speech
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.word.word)
                    .font(.title2.bold())

                Text(card.word.partOfSpeech)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Pronunciation
            HStack(spacing: 6) {
                Image(systemName: "speaker.wave.2")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(card.word.pronunciation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Definition
            Text(card.word.definition)
                .font(.body)
                .lineSpacing(4)

            // Etymology
            VStack(alignment: .leading, spacing: 4) {
                Text("Origin")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(card.word.etymology)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("How well did you know this word?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ratingButton(
                    label: "No clue",
                    icon: "xmark.circle",
                    color: .red,
                    quality: .noClue
                )

                ratingButton(
                    label: "Had a hunch",
                    icon: "questionmark.circle",
                    color: .orange,
                    quality: .hadAHunch
                )

                ratingButton(
                    label: "Knew it",
                    icon: "checkmark.circle",
                    color: .green,
                    quality: .knewIt
                )
            }
        }
    }

    private func ratingButton(
        label: String,
        icon: String,
        color: Color,
        quality: SM2Engine.Quality
    ) -> some View {
        Button {
            withAnimation(.easeInOut) {
                hasRated = true
            }
            onRate(quality)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.12), in: .rect(cornerRadius: 12))
            .foregroundStyle(color)
        }
    }
}

#Preview {
    SessionCardView(
        card: SessionManager.SessionCard(
            word: allWords[0],
            scenarioIndex: 0,
            isReview: false
        ),
        onRate: { _ in }
    )
}
