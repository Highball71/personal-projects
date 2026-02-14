import SwiftUI
import SwiftData

/// The card-flow session for etymology words. Presents cards one at a time,
/// handles rating, updates SM-2 progress, and shows a session summary at the end.
struct EtymologySessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sessionType: EtymologySessionManager.SessionType

    @State private var session: EtymologySessionManager?
    @State private var cardTransitionID = UUID()

    // Session summary stats
    @State private var wordsRated: Int = 0
    @State private var newWordsLearned: Int = 0
    @State private var wordsMastered: Int = 0

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if session.isComplete {
                        sessionSummary
                    } else if let card = session.currentCard {
                        EtymologyCardView(card: card) { quality in
                            rateWord(card: card, quality: quality)
                        }
                        .id(cardTransitionID)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }
                } else {
                    noWordsView
                }
            }
            .navigationTitle("Deeper Than You Knew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                if let session, !session.isComplete {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("\(session.currentIndex + 1)/\(session.totalCards)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if session == nil {
                let mgr = EtymologySessionManager(modelContext: modelContext, type: sessionType)
                if mgr.cards.isEmpty {
                    session = nil
                } else {
                    session = mgr
                }
            }
        }
    }

    // MARK: - Rate a Word

    private func rateWord(card: EtymologySessionManager.SessionCard, quality: SM2Engine.Quality) {
        let wordID = card.word.id
        let descriptor = FetchDescriptor<EtymologyProgress>(
            predicate: #Predicate { $0.wordID == wordID }
        )
        let existing = try? modelContext.fetch(descriptor)
        let progress: EtymologyProgress

        if let found = existing?.first {
            progress = found
        } else {
            progress = EtymologyProgress(wordID: wordID)
            modelContext.insert(progress)
            newWordsLearned += 1
        }

        // Run SM-2 algorithm
        let wasMastered = progress.status == .mastered
        let result = SM2Engine.calculate(
            quality: quality,
            currentEaseFactor: progress.easeFactor,
            currentInterval: progress.interval,
            currentRepetitions: progress.repetitions
        )
        progress.applyReview(result)

        if !wasMastered && progress.status == .mastered {
            wordsMastered += 1
        }

        wordsRated += 1

        // Update daily activity (shared with main mode)
        updateDailyActivity(isNewWord: !card.isReview)

        // Advance to next card
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.3)) {
                cardTransitionID = UUID()
                session?.advance()
            }
        }
    }

    // MARK: - Daily Activity

    private func updateDailyActivity(isNewWord: Bool) {
        let today = Calendar.current.startOfDay(for: Date())
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.date == today }
        )

        let activity: DailyActivity
        if let existing = try? modelContext.fetch(descriptor), let found = existing.first {
            activity = found
        } else {
            activity = DailyActivity(date: Date())
            modelContext.insert(activity)
        }

        activity.wordsReviewed += 1
        if isNewWord {
            activity.wordsLearned += 1
        }
    }

    // MARK: - Session Summary

    private var sessionSummary: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Session Complete!")
                .font(.title.bold())

            VStack(spacing: 12) {
                summaryRow(icon: "book.fill", label: "Origins explored", value: "\(wordsRated)", color: .blue)

                if newWordsLearned > 0 {
                    summaryRow(icon: "sparkles", label: "New discoveries", value: "\(newWordsLearned)", color: .green)
                }

                if wordsMastered > 0 {
                    summaryRow(icon: "star.fill", label: "Words mastered", value: "\(wordsMastered)", color: .yellow)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.tint, in: .rect(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }

    // MARK: - No Words View

    private var noWordsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            Text("All caught up!")
                .font(.title2.bold())
            Text("No etymology words are due for review.\nCome back later!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    EtymologySessionView(sessionType: .mixed)
        .modelContainer(for: [EtymologyProgress.self, DailyActivity.self], inMemory: true)
}
