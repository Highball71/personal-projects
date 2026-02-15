import SwiftUI

/// A single card in an etymology session.
/// Shows the word with a casual intro, then reveals the surprising origin on tap.
struct EtymologyCardView: View {
    let card: EtymologySessionManager.SessionCard
    let onRate: (SM2Engine.Quality) -> Void

    @State private var showingOrigin = false
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

                    // Word display
                    VStack(spacing: 16) {
                        Text(card.word.word)
                            .font(.largeTitle.bold())
                            .foregroundStyle(.primary)

                        Text(card.word.originLanguage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray5), in: .capsule)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)

                    // Casual intro
                    if !showingOrigin {
                        Text(card.word.casualIntro)
                            .font(.body)
                            .lineSpacing(5)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)

                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                showingOrigin = true
                            }
                        } label: {
                            Label("Reveal Origin", systemImage: "eye")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.tint, in: .rect(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                    } else {
                        // Show intro (non-tappable)
                        Text(card.word.casualIntro)
                            .font(.body)
                            .lineSpacing(5)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                    }

                    // Origin reveal
                    if showingOrigin {
                        originCard
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
            if showingOrigin && !hasRated {
                ratingButtons
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if hasRated {
                Text("Got it!")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Origin Card

    private var originCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Breakdown header
            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(card.word.breakdown)
                    .font(.headline)
                    .foregroundStyle(.tint)
            }

            // Literal meaning
            Text("= \"\(card.word.literalMeaning)\"")
                .font(.title3.bold())

            Divider()

            // Origin story
            Text(card.word.originStory)
                .font(.body)
                .lineSpacing(5)
                .foregroundStyle(.primary)
        }
        .padding(20)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        VStack(spacing: 12) {
            Text("Did you know the origin?")
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
    EtymologyCardView(
        card: EtymologySessionManager.SessionCard(
            word: allEtymologyWords[0],
            isReview: false
        ),
        onRate: { _ in }
    )
}
