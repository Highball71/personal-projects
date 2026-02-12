import SwiftUI

/// A card overlay that shows the definition of the vocabulary word.
/// Appears when the user taps the highlighted word in the scenario.
struct DefinitionCardView: View {
    let word: VocabularyWord
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Definition card
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(word.word)
                        .font(.title.bold())

                    Text(word.partOfSpeech)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text(word.definition)
                    .font(.body)
                    .lineSpacing(4)
            }
            .padding(24)
            .background(.regularMaterial, in: .rect(cornerRadius: 20))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    DefinitionCardView(
        word: VocabularyWord(
            id: "preview",
            word: "Exculpatory",
            definition: "Tending to clear someone from blame or guilt",
            partOfSpeech: "adjective",
            scenario: "Preview scenario"
        ),
        onDismiss: {}
    )
}
