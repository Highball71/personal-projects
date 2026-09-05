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

    @State private var narrator = Narrator()
    @State private var index = 0
    @State private var revealed = false
    @State private var showSceneText = false
    @State private var composingScene = false
    // Staged card disclosure: definition and neighbours appear as spoken
    @State private var definitionRevealed = false
    @State private var neighborsRevealed = false

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
                        narrator.stop()
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
        .interactiveDismissDisabled(narrator.phase == .speakingScene)
        .onAppear {
            // Pre-generate this lesson's audio in the background. The first
            // word may still play via live synthesis; later ones (and
            // replays) get the generated files.
            let requests = words.flatMap { AudioStore.AssetRequest.lessonAssets(for: $0) }
            Task.detached(priority: .utility) {
                await AudioStore.shared.ensureGenerated(requests)
            }
            startWord()
        }
        // Each element of the card lands as it is spoken — word, then
        // definition, then the neighbour distinction — regardless of whether
        // the audio came from files or live synthesis
        .onChange(of: narrator.phase) { _, newPhase in
            switch newPhase {
            case .speakingWord where !revealed:
                reveal()
            case .speakingDefinition:
                withAnimation { definitionRevealed = true }
            case .speakingNeighbor:
                withAnimation { neighborsRevealed = true }
            case .finished:
                // However we got here, the full card should be showing
                withAnimation {
                    definitionRevealed = true
                    neighborsRevealed = true
                }
            default:
                break
            }
        }
        .sheet(isPresented: $composingScene) {
            if let word = currentWord {
                SceneComposerView(word: word)
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
                .symbolEffect(.pulse, isActive: narrator.phase == .speakingScene)
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

        WordCardView(
            word: word,
            onSpeak: { _ in
                narrator.speak(text: word.word, asset: .word(for: word), style: .word)
            },
            showDefinition: definitionRevealed,
            showNeighbors: neighborsRevealed
        )

        Button {
            composingScene = true
        } label: {
            Label("Write your own scene for it", systemImage: "square.and.pencil")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func bottomBar(for word: SeedWord) -> some View {
        HStack(spacing: 12) {
            if !revealed {
                Button {
                    narrator.speakLesson(for: word)
                } label: {
                    Label("Replay", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    // Manual reveal skips the audio, so show the whole card
                    narrator.stop()
                    reveal()
                    definitionRevealed = true
                    neighborsRevealed = true
                } label: {
                    Label("Reveal", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    narrator.speak(text: word.systemScene, asset: .scene(for: word))
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
        switch narrator.phase {
        case .speakingScene: return "waveform"
        case .beatOfSilence: return "ellipsis"
        default: return "headphones"
        }
    }

    private var phaseCaption: String {
        switch narrator.phase {
        case .speakingScene: return "Listen. There's a word for this…"
        case .beatOfSilence: return "…"
        default: return "Ready"
        }
    }

    private func startWord() {
        guard let word = currentWord else { return }
        revealed = false
        showSceneText = false
        definitionRevealed = false
        neighborsRevealed = false
        narrator.speakLesson(for: word)
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
        narrator.stop()
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
