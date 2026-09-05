import Foundation
import SwiftData

/// A scene the user wrote themselves (design decision #6).
/// Two directions:
///  - forWord: written for a word just learned (retention; phase 2 UI)
///  - seekingWord: written for a feeling with no word yet; the app finds
///    the word later (phase 3, doubles as content pipeline)
/// The model ships in phase 1 so the schema is stable before the UI exists.
@Model
final class UserScene {
    @Attribute(.unique) var id: UUID

    /// The word this scene was written for; nil for seekingWord scenes
    var wordID: String?

    var text: String

    /// "forWord" | "seekingWord"
    var kind: String

    var createdAt: Date

    /// For seekingWord scenes: the word the app eventually matched, if any
    var resolvedWordID: String?

    init(wordID: String?, text: String, kind: SceneKind, createdAt: Date = Date()) {
        self.id = UUID()
        self.wordID = wordID
        self.text = text
        self.kind = kind.rawValue
        self.createdAt = createdAt
    }

    enum SceneKind: String {
        case forWord
        case seekingWord
    }
}
