import Foundation

/// Builds recognition-review questions (design decision #4): show a scene,
/// ask which learned word fits. Never "here's the word, what does it mean."
struct ReviewBuilder {

    /// Cap per session so reviews stay a coffee-length habit.
    static let maxQuestionsPerSession = 10

    /// Answer choices per question, including the right one.
    static let choiceCount = 4

    struct Question: Identifiable {
        let id: String              // target word ID
        let target: SeedWord
        let sceneText: String       // phase 1 limitation: the system scene again
        let choices: [SeedWord]     // shuffled, contains target
    }

    /// Builds a session from the words due today.
    ///
    /// Distractor policy: prefer other LEARNED words from the same domain —
    /// those are the distinctions worth testing (decision #3). Fall back to
    /// learned words from any domain, then to unlearned same-tier words so a
    /// brand-new user still gets four plausible choices.
    ///
    /// Phase 1 limitation (open question): the scene shown is the same system
    /// scene from the lesson. Fresh scenes per review arrive in phase 2.
    static func buildSession(dueWordIDs: [String], learnedWordIDs: Set<String>) -> [Question] {
        let dueWords = dueWordIDs.compactMap { SeedStore.wordsByID[$0] }

        return dueWords
            .shuffled()
            .prefix(maxQuestionsPerSession)
            .compactMap { target in
                let distractors = pickDistractors(for: target, learnedWordIDs: learnedWordIDs)
                // A question with fewer than 2 distractors isn't a real test — skip
                guard distractors.count >= 2 else { return nil }
                return Question(
                    id: target.id,
                    target: target,
                    sceneText: target.systemScene,
                    choices: (distractors + [target]).shuffled()
                )
            }
    }

    private static func pickDistractors(for target: SeedWord, learnedWordIDs: Set<String>) -> [SeedWord] {
        let needed = choiceCount - 1
        let pool = SeedStore.mainWords.filter { $0.id != target.id }

        // Ranked pools, best teaching value first
        let learnedSameDomain = pool.filter { learnedWordIDs.contains($0.id) && $0.domain == target.domain }
        let learnedOther = pool.filter { learnedWordIDs.contains($0.id) && $0.domain != target.domain }
        let unlearnedSameTier = pool.filter { !learnedWordIDs.contains($0.id) && $0.tier == target.tier }
        let anythingElse = pool.filter { !learnedWordIDs.contains($0.id) && $0.tier != target.tier }

        var picked: [SeedWord] = []
        for source in [learnedSameDomain, learnedOther, unlearnedSameTier, anythingElse] {
            guard picked.count < needed else { break }
            picked += source.shuffled().prefix(needed - picked.count)
        }
        return picked
    }
}
