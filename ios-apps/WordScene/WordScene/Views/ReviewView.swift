import SwiftUI
import SwiftData

/// Recognition review (decision #4): a scene is shown, the user picks which
/// learned word fits. Never "here's the word, what does it mean."
struct ReviewView: View {
    let questions: [ReviewBuilder.Question]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var speech = SpeechService()
    @State private var index = 0
    @State private var selectedID: String?   // nil until the user answers
    @State private var correctCount = 0

    private var currentQuestion: ReviewBuilder.Question? {
        index < questions.count ? questions[index] : nil
    }

    private var answered: Bool { selectedID != nil }

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
                        speech.stop()
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
        .onDisappear { speech.stop() }
    }

    @ViewBuilder
    private func questionContent(_ question: ReviewBuilder.Question) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Which word fits this moment?")
                        .font(.headline)
                    Spacer()
                    Button {
                        speech.speak(question.sceneText)
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

                VStack(spacing: 10) {
                    ForEach(question.choices) { choice in
                        choiceButton(choice, in: question)
                    }
                }

                // After answering, surface the distinction — the teaching moment
                if answered, selectedID != question.target.id,
                   let picked = question.choices.first(where: { $0.id == selectedID }),
                   let distinction = distinctionText(target: question.target, picked: picked) {
                    Text(distinction)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
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

    @ViewBuilder
    private func choiceButton(_ choice: SeedWord, in question: ReviewBuilder.Question) -> some View {
        Button {
            answer(choice, in: question)
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

    /// If the user picked a word that is a listed neighbour of the target (or
    /// vice versa), show the exact distinction they just blurred.
    private func distinctionText(target: SeedWord, picked: SeedWord) -> String? {
        if let n = target.neighbors.first(where: { $0.word.lowercased() == picked.word.lowercased() }) {
            return n.distinction
        }
        if let n = picked.neighbors.first(where: { $0.word.lowercased() == target.word.lowercased() }) {
            return n.distinction
        }
        return "The answer was \"\(target.word)\" — \(target.definition.lowercasedFirst())"
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

    private func answer(_ choice: SeedWord, in question: ReviewBuilder.Question) {
        guard !answered else { return }
        speech.stop()
        selectedID = choice.id
        let correct = choice.id == question.target.id
        if correct { correctCount += 1 }

        // Update scheduling + mastery evidence on the word's state record.
        // applyRecognitionOutcome can promote seen → recognizes, and never
        // beyond producesOnPrompt (hard constraint lives in WordState).
        let wordID = question.target.id
        let descriptor = FetchDescriptor<WordState>(predicate: #Predicate { $0.wordID == wordID })
        if let state = try? modelContext.fetch(descriptor).first {
            state.applyRecognitionOutcome(correct: correct)
        }
        ActivityRecorder.recordRecognition(wordID: wordID, correct: correct, in: modelContext)
    }

    private func advance() {
        selectedID = nil
        index += 1
    }
}

private extension String {
    func lowercasedFirst() -> String {
        guard let first = first else { return self }
        return first.lowercased() + dropFirst()
    }
}

#Preview {
    ReviewView(questions: ReviewBuilder.buildSession(
        dueWordIDs: SeedStore.mainWords.prefix(5).map(\.id),
        learnedWordIDs: Set(SeedStore.mainWords.prefix(10).map(\.id))
    ))
    .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
