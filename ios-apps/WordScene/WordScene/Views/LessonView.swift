import SwiftUI
import SwiftData

/// The voice-first learning loop (decisions #1 and #7):
/// hear a vivid scene WITHOUT the word → a beat of silence → hear the word,
/// and only then see the card. The gap is the teaching, so the scene text
/// stays hidden unless the user asks for it, and nothing on screen names the
/// word until the reveal.
struct LessonView: View {
    let words: [SeedWord]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var speech = SpeechService()
    @State private var index = 0
    @State private var revealed = false
    @State private var showSceneText = false

    private var currentWord: SeedWord? {
        index < words.count ? words[index] : nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let word = currentWord {
                    lessonContent(for: word)
                } else {
                    finishedContent
                }
            }
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        speech.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(min(index + 1, words.count)) of \(words.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .interactiveDismissDisabled(speech.phase == .speakingScene)
        .onAppear { startWord() }
        // When the spoken word begins, the visual reveal lands with it
        .onChange(of: speech.phase) { _, newPhase in
            if newPhase == .speakingWord && !revealed {
                reveal()
            }
        }
    }

    // MARK: - Listening / reveal stages

    @ViewBuilder
    private func lessonContent(for word: SeedWord) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !revealed {
                    listeningStage(for: word)
                } else {
                    revealedStage(for: word)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar(for: word)
        }
    }

    /// Before the reveal: a listening posture, not a reading one.
    @ViewBuilder
    private func listeningStage(for word: SeedWord) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)

            Image(systemName: phaseSymbol)
                .font(.system(size: 64))
                .foregroundStyle(.indigo)
                .symbolEffect(.pulse, isActive: speech.phase == .speakingScene)
                .frame(maxWidth: .infinity)

            Text(phaseCaption)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            if showSceneText {
                Text(word.systemScene)
                    .font(.body)
                    .lineSpacing(4)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .transition(.opacity)
            } else {
                Button("Show the scene as text") {
                    withAnimation { showSceneText = true }
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// After the reveal: the scene stays visible above the card so the user
    /// can re-read the moment with the word now in hand.
    @ViewBuilder
    private func revealedStage(for word: SeedWord) -> some View {
        Text(word.systemScene)
            .font(.subheadline)
            .lineSpacing(3)
            .foregroundStyle(.secondary)
            .padding()
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

        WordCardView(word: word) { text in
            speech.speak(text, slowly: true)
        }
    }

    private func bottomBar(for word: SeedWord) -> some View {
        HStack(spacing: 12) {
            if !revealed {
                Button {
                    speech.speakLesson(scene: word.systemScene, word: word.word)
                } label: {
                    Label("Replay", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    speech.stop()
                    reveal()
                } label: {
                    Label("Reveal", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    speech.speak(word.systemScene)
                } label: {
                    Label("Hear scene", systemImage: "speaker.wave.2")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    advance()
                } label: {
                    Label(index + 1 < words.count ? "Next word" : "Finish", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.bar)
    }

    private var finishedContent: some View {
        ContentUnavailableView {
            Label("Lesson complete", systemImage: "checkmark.seal.fill")
        } description: {
            Text("These words come back tomorrow as fresh scenes. The real test is hearing one fit.")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Flow

    private var phaseSymbol: String {
        switch speech.phase {
        case .speakingScene: return "waveform"
        case .beatOfSilence: return "ellipsis"
        default: return "headphones"
        }
    }

    private var phaseCaption: String {
        switch speech.phase {
        case .speakingScene: return "Listen. There's a word for this…"
        case .beatOfSilence: return "…"
        default: return "Ready"
        }
    }

    private func startWord() {
        guard let word = currentWord else { return }
        revealed = false
        showSceneText = false
        speech.speakLesson(scene: word.systemScene, word: word.word)
    }

    /// Marks the word as seen: this is the moment the gap gets its name.
    private func reveal() {
        guard let word = currentWord, !revealed else { return }
        withAnimation { revealed = true }

        // First meeting → create the progress record and log the event.
        // (Replaying a lesson for an already-known word would just re-reveal.)
        let wordID = word.id
        let descriptor = FetchDescriptor<WordState>(predicate: #Predicate { $0.wordID == wordID })
        if (try? modelContext.fetch(descriptor).first) == nil {
            modelContext.insert(WordState(wordID: wordID))
            ActivityRecorder.recordReveal(wordID: wordID, in: modelContext)
        }
    }

    private func advance() {
        speech.stop()
        index += 1
        if currentWord != nil {
            startWord()
        }
    }
}

#Preview {
    LessonView(words: Array(SeedStore.mainWords.prefix(3)))
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
