import Foundation

/// Builds review questions (design decision #4): a scene is shown, and the
/// user either recognizes the word among choices or produces it outright.
/// Never "here's the word, what does it mean."
///
/// Question kind follows the mastery ladder: words still at `seen` get
/// recognition questions; words at `recognizes` and above get production
/// prompts (the next rung's evidence). Scenes come fresh — the seed's
/// reviewScene or a scene the user wrote — never just the lesson replay
/// unless nothing else exists.
struct ReviewBuilder {

    /// Cap per session so reviews stay a coffee-length habit.
    static let maxQuestionsPerSession = 10

    /// Answer choices per recognition question, including the right one.
    static let choiceCount = 4

    enum Kind {
        case recognition   // pick the word that fits
        case production    // type the word that fits
    }

    struct Question: Identifiable {
        let id: String              // target word ID
        let kind: Kind
        let target: SeedWord
        let sceneText: String
        let sceneAsset: AudioStore.AssetRequest?  // nil for user-authored scenes (no pre-generated audio yet)
        let choices: [SeedWord]     // recognition only; empty for production
    }

    /// Everything the builder needs to know about the user's progress.
    struct Input {
        let dueWordIDs: [String]
        let learnedWordIDs: Set<String>
        let masteryByID: [String: MasteryStage]
        let userScenesByWordID: [String: [String]]
    }

    static func buildSession(_ input: Input) -> [Question] {
        let dueWords = input.dueWordIDs.compactMap { SeedStore.wordsByID[$0] }

        return dueWords
            .shuffled()
            .prefix(maxQuestionsPerSession)
            .compactMap { target in
                let mastery = input.masteryByID[target.id] ?? .seen
                let scene = pickScene(for: target, userScenes: input.userScenesByWordID[target.id] ?? [])

                if mastery >= .recognizes {
                    return Question(
                        id: target.id, kind: .production, target: target,
                        sceneText: scene.text, sceneAsset: scene.asset, choices: []
                    )
                } else {
                    let distractors = pickDistractors(for: target, learnedWordIDs: input.learnedWordIDs)
                    // A question with fewer than 2 distractors isn't a real test — skip
                    guard distractors.count >= 2 else { return nil }
                    return Question(
                        id: target.id, kind: .recognition, target: target,
                        sceneText: scene.text, sceneAsset: scene.asset,
                        choices: (distractors + [target]).shuffled()
                    )
                }
            }
    }

    /// Audio assets worth pre-generating for a session, so scenes can play
    /// from files rather than live synthesis.
    static func audioRequests(for questions: [Question]) -> [AudioStore.AssetRequest] {
        questions.compactMap(\.sceneAsset)
    }

    /// Fresh-scene policy: a user-authored scene (rotating randomly) beats the
    /// seed's reviewScene, which beats replaying the lesson scene. The lesson
    /// scene is the fallback of last resort only.
    private static func pickScene(for target: SeedWord, userScenes: [String]) -> (text: String, asset: AudioStore.AssetRequest?) {
        if let userScene = userScenes.randomElement() {
            return (userScene, nil)
        }
        if target.reviewScene != nil, let asset = AudioStore.AssetRequest.reviewScene(for: target) {
            return (asset.text, asset)
        }
        return (target.systemScene, .scene(for: target))
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
