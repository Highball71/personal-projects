import SwiftUI
import SwiftData

/// Review session (decision #4): a fresh scene, and the user either picks the
/// learned word that fits (recognition) or types it (production — the next
/// rung's evidence). Never "here's the word, what does it mean."
struct ReviewView: View {
    let questions: [ReviewBuilder.Question]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var narrator = Narrator()
    @State private var index = 0
    @State private var selectedID: String?      // recognition answer
    @State private var typedAnswer = ""         // production answer in progress
    @State private var productionResult: Bool?  // production answered: correct?
    @State private var correctCount = 0
    @FocusState private var answerFieldFocused: Bool

    private var currentQuestion: ReviewBuilder.Question? {
        index < questions.count ? questions[index] : nil
    }

    private var answered: Bool {
        selectedID != nil || productionResult != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let question = currentQuestion {
                    questionContent(question)
                } else {
                    finishedContent
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        narrator.stop()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(min(index + 1, questions.count)) of \(questions.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            // Pre-generate this session's scene audio in the background;
            // anything not ready in time plays via live synthesis instead.
            let requests = ReviewBuilder.audioRequests(for: questions)
            Task.detached(priority: .utility) {
                await AudioStore.shared.ensureGenerated(requests)
            }
        }
        .onDisappear { narrator.stop() }
    }

    @ViewBuilder
    private func questionContent(_ question: ReviewBuilder.Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(question.kind == .recognition
                         ? "Which word fits this moment?"
                         : "Say the word that fits — then type it")
                        .font(.headline)
                    Spacer()
                    Button {
                        narrator.speak(text: question.sceneText, asset: question.sceneAsset)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                    }
                    .accessibilityLabel("Hear the scene")
                }

                Text(question.sceneText)
                    .font(.body)
                    .lineSpacing(4)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                switch question.kind {
                case .recognition:
                    VStack(spacing: 10) {
                        ForEach(question.choices) { choice in
                            choiceButton(choice, in: question)
                        }
                    }
                case .production:
                    productionAnswerArea(question)
                }

                if answered {
                    teachingMoment(question)
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if answered {
                Button {
                    advance()
                } label: {
                    Label(index + 1 < questions.count ? "Next" : "Finish", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
        }
    }

    // MARK: - Recognition UI

    @ViewBuilder
    private func choiceButton(_ choice: SeedWord, in question: ReviewBuilder.Question) -> some View {
        Button {
            answerRecognition(choice, in: question)
        } label: {
            HStack {
                Text(choice.word)
                    .font(.body.weight(.medium))
                Spacer()
                if answered {
                    if choice.id == question.target.id {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if choice.id == selectedID {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(choiceBackground(choice, in: question), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(answered)
    }

    private func choiceBackground(_ choice: SeedWord, in question: ReviewBuilder.Question) -> Color {
        guard answered else { return Color(.secondarySystemBackground) }
        if choice.id == question.target.id { return .green.opacity(0.15) }
        if choice.id == selectedID { return .red.opacity(0.15) }
        return Color(.secondarySystemBackground)
    }

    // MARK: - Production UI

    @ViewBuilder
    private func productionAnswerArea(_ question: ReviewBuilder.Question) -> some View {
        if let result = productionResult {
            HStack(spacing: 10) {
                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result ? .green : .red)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(question.target.word)
                        .font(.title3.weight(.semibold))
                    if !result && !typedAnswer.trimmed().isEmpty {
                        Text("You wrote: \(typedAnswer.trimmed())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((result ? Color.green : .red).opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 10) {
                TextField("The word is…", text: $typedAnswer)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($answerFieldFocused)
                    .onSubmit { answerProduction(question) }

                HStack(spacing: 12) {
                    Button("I don't have it") {
                        // Giving up is an honest miss — schedule it sooner
                        typedAnswer = ""
                        answerProduction(question, gaveUp: true)
                    }
                    .buttonStyle(.bordered)

                    Button("Check") {
                        answerProduction(question)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(typedAnswer.trimmed().isEmpty)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .onAppear { answerFieldFocused = true }
        }
    }

    // MARK: - Shared teaching moment

    /// After answering, surface the precise distinction — that's the teaching.
    @ViewBuilder
    private func teachingMoment(_ question: ReviewBuilder.Question) -> some View {
        let wrongPick = question.choices.first { $0.id == selectedID && $0.id != question.target.id }
        if let picked = wrongPick, let distinction = distinctionText(target: question.target, picked: picked) {
            infoBox(distinction)
        } else if selectedID != question.target.id || productionResult == false {
            infoBox("\"\(question.target.word)\" — \(question.target.definition.lowercasedFirst())")
        }
    }

    private func infoBox(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    /// If the user picked a listed neighbour of the target (or vice versa),
    /// show the exact distinction they just blurred.
    private func distinctionText(target: SeedWord, picked: SeedWord) -> String? {
        if let n = target.neighbors.first(where: { $0.word.lowercased() == picked.word.lowercased() }) {
            return n.distinction
        }
        if let n = picked.neighbors.first(where: { $0.word.lowercased() == target.word.lowercased() }) {
            return n.distinction
        }
        return nil
    }

    private var finishedContent: some View {
        ContentUnavailableView {
            Label("Review complete", systemImage: "checkmark.seal.fill")
        } description: {
            Text("\(correctCount) of \(questions.count) placed correctly. Words you missed come back sooner.")
        } actions: {
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Flow

    private func answerRecognition(_ choice: SeedWord, in question: ReviewBuilder.Question) {
        guard !answered else { return }
        narrator.stop()
        selectedID = choice.id
        let correct = choice.id == question.target.id
        if correct { correctCount += 1 }

        // applyRecognitionOutcome can promote seen → recognizes, and never
        // beyond producesOnPrompt (hard constraint lives in WordState)
        if let state = fetchState(question.target.id) {
            state.applyRecognitionOutcome(correct: correct)
        }
        ActivityRecorder.recordRecognition(wordID: question.target.id, correct: correct, in: modelContext)
    }

    private func answerProduction(_ question: ReviewBuilder.Question, gaveUp: Bool = false) {
        guard !answered else { return }
        narrator.stop()
        answerFieldFocused = false
        let correct = !gaveUp && typedAnswer.trimmed().lowercased() == question.target.word.lowercased()
        productionResult = correct
        if correct { correctCount += 1 }

        if let state = fetchState(question.target.id) {
            state.applyProductionOutcome(correct: correct)
        }
        ActivityRecorder.recordProduction(wordID: question.target.id, correct: correct, in: modelContext)
    }

    private func fetchState(_ wordID: String) -> WordState? {
        let descriptor = FetchDescriptor<WordState>(predicate: #Predicate { $0.wordID == wordID })
        return try? modelContext.fetch(descriptor).first
    }

    private func advance() {
        selectedID = nil
        typedAnswer = ""
        productionResult = nil
        index += 1
    }
}

private extension String {
    func lowercasedFirst() -> String {
        guard let first = first else { return self }
        return first.lowercased() + dropFirst()
    }
    func trimmed() -> String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    ReviewView(questions: ReviewBuilder.buildSession(.init(
        dueWordIDs: SeedStore.mainWords.prefix(5).map(\.id),
        learnedWordIDs: Set(SeedStore.mainWords.prefix(10).map(\.id)),
        masteryByID: [:],
        userScenesByWordID: [:]
    )))
    .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
