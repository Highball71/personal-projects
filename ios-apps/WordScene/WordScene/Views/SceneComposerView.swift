import SwiftUI
import SwiftData

/// Write-your-own-scene (design decision #6a): after learning a word, the user
/// writes a moment of their own that the word names. Owning the word through a
/// scene is the retention move — and the scene becomes future review material.
///
/// The same hard rule as system scenes applies: the scene must NOT contain the
/// word. The gap is the point; a scene with the word in it tests nothing.
struct SceneComposerView: View {
    let word: SeedWord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""

    private static let minWords = 20
    private static let maxWords = 120

    private var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    /// The word (or an obvious form of it) appearing in the scene.
    /// Same stem heuristic the seed validation uses.
    private var containsTheWord: Bool {
        text.lowercased().contains(word.word.lowercased().prefix(5))
    }

    private var validationMessage: String? {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return nil }
        if containsTheWord {
            return "The scene can't contain \"\(word.word)\" — the gap is the point. Describe the moment; let the word stay missing."
        }
        if wordCount < Self.minWords {
            return "Keep going — a scene needs at least \(Self.minWords) words to get vivid. (\(wordCount) so far)"
        }
        if wordCount > Self.maxWords {
            return "Over \(Self.maxWords) words — trim it to the sharpest moment. (\(wordCount) now)"
        }
        return nil
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && validationMessage == nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Write a specific moment that *\(word.word)* names — without using the word. Somewhere you've actually been, if you can.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    .frame(minHeight: 180)

                HStack {
                    if let message = validationMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(wordCount) words")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Your scene")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let scene = UserScene(
            wordID: word.id,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: .forWord
        )
        modelContext.insert(scene)
        ActivityRecorder.recordSceneAuthored(wordID: word.id, in: modelContext)
        dismiss()
    }
}

#Preview {
    SceneComposerView(word: SeedStore.mainWords.first!)
        .modelContainer(for: [WordState.self, UserScene.self, ReviewLog.self, DailyActivity.self], inMemory: true)
}
