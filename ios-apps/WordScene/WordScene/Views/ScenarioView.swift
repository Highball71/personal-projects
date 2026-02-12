import SwiftUI
import SwiftData

struct ScenarioView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var progressEntries: [WordProgress]

    // The current word being displayed
    @State private var currentWord: VocabularyWord?
    // Whether the definition card is showing
    @State private var showingDefinition = false
    // Whether the user has responded (Knew it / New to me) for this word
    @State private var hasResponded = false
    // Slide-in animation trigger
    @State private var cardOffset: CGFloat = 0

    /// Words the user hasn't seen yet
    private var unseenWords: [VocabularyWord] {
        let seenIDs = Set(progressEntries.map(\.wordID))
        return allWords.filter { !seenIDs.contains($0.id) }
    }

    /// Pick a random unseen word, or a random word if all have been seen
    private func pickNextWord() {
        withAnimation(.easeInOut(duration: 0.3)) {
            cardOffset = -UIScreen.main.bounds.width
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showingDefinition = false
            hasResponded = false

            if let next = unseenWords.randomElement() {
                currentWord = next
            } else {
                // All words seen — cycle through them again
                currentWord = allWords.randomElement()
            }

            cardOffset = UIScreen.main.bounds.width
            withAnimation(.easeInOut(duration: 0.3)) {
                cardOffset = 0
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if let word = currentWord {
                    scenarioCard(for: word)
                        .offset(x: cardOffset)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    if value.translation.width < -50 {
                                        pickNextWord()
                                    }
                                }
                        )
                } else {
                    // All done state
                    allDoneView
                }

                // Definition overlay
                if showingDefinition, let word = currentWord {
                    DefinitionCardView(word: word) {
                        withAnimation(.spring(duration: 0.3)) {
                            showingDefinition = false
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .navigationTitle("WordScene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Show progress count in the nav bar
                    Text("\(progressEntries.count)/\(allWords.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            if currentWord == nil {
                currentWord = unseenWords.randomElement() ?? allWords.randomElement()
            }
        }
    }

    // MARK: - Scenario Card

    @ViewBuilder
    private func scenarioCard(for word: VocabularyWord) -> some View {
        VStack(spacing: 24) {
            Spacer()

            // The scenario text with the vocabulary word highlighted
            scenarioText(for: word)
                .padding(.horizontal, 24)

            if !hasResponded {
                Text("Tap the highlighted word to see its definition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if hasResponded {
                // Next button after responding
                Button {
                    pickNextWord()
                } label: {
                    Label("Next", systemImage: "arrow.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.tint, in: .rect(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Knew it / New to me buttons
                HStack(spacing: 16) {
                    Button {
                        recordProgress(knewIt: true, for: word)
                    } label: {
                        Label("Knew it", systemImage: "checkmark.circle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green.opacity(0.15), in: .rect(cornerRadius: 14))
                            .foregroundStyle(.green)
                    }

                    Button {
                        recordProgress(knewIt: false, for: word)
                    } label: {
                        Label("New to me", systemImage: "lightbulb")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange.opacity(0.15), in: .rect(cornerRadius: 14))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 24)
            }

            // Swipe hint
            Text("Swipe left for next word")
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .padding(.bottom, 8)
        }
        .padding(.vertical)
    }

    // MARK: - Scenario Text Builder

    /// Builds the scenario text with the vocabulary word tappable and highlighted.
    /// Finds the word in the scenario (case-insensitive) and makes it bold + colored + tappable.
    @ViewBuilder
    private func scenarioText(for word: VocabularyWord) -> some View {
        let scenario = word.scenario
        let target = word.word.lowercased()

        // Find the range of the word in the scenario (case-insensitive)
        if let range = scenario.lowercased().range(of: target) {
            let before = String(scenario[scenario.startIndex..<range.lowerBound])
            let matched = String(scenario[range])
            let after = String(scenario[range.upperBound..<scenario.endIndex])

            // Build a composite Text view
            VStack(spacing: 0) {
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
                    withAnimation(.spring(duration: 0.3)) {
                        showingDefinition = true
                    }
                }
            }
        } else {
            // Fallback if word isn't found in scenario
            Text(scenario)
                .font(.title3)
                .lineSpacing(6)
        }
    }

    // MARK: - All Done View

    private var allDoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "party.popper")
                .font(.system(size: 60))
                .foregroundStyle(.tint)
            Text("You've seen all the words!")
                .font(.title2.bold())
            Text("Tap below to keep practicing.")
                .foregroundStyle(.secondary)
            Button("Start Over") {
                currentWord = allWords.randomElement()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Progress Recording

    private func recordProgress(knewIt: Bool, for word: VocabularyWord) {
        // Check if there's already progress for this word
        let existingEntry = progressEntries.first { $0.wordID == word.id }

        if let entry = existingEntry {
            // Update: if they now knew it, mark as mastered
            if knewIt {
                entry.knewIt = true
                entry.dateEncountered = Date()
            }
        } else {
            // Create new progress entry
            let progress = WordProgress(wordID: word.id, knewIt: knewIt)
            modelContext.insert(progress)
        }

        withAnimation(.easeInOut) {
            hasResponded = true
        }
    }
}

#Preview {
    ScenarioView()
        .modelContainer(for: WordProgress.self, inMemory: true)
}
