import Foundation

/// The mastery ladder (design decision #5). Recognition is a lower rung;
/// mastery means using the word unprompted in real life.
enum MasteryStage: String, Codable, CaseIterable, Comparable {
    case seen               // word was revealed in a lesson
    case recognizes         // picks the word out in fresh contexts, spaced over days
    case producesOnPrompt   // supplies the word when shown a scene (phase 2 UI)
    case usesUnprompted     // reported using it in the wild — ONLY reachable by self-report

    /// Ladder order, for comparisons and progress displays.
    var rung: Int {
        switch self {
        case .seen: return 0
        case .recognizes: return 1
        case .producesOnPrompt: return 2
        case .usesUnprompted: return 3
        }
    }

    static func < (lhs: MasteryStage, rhs: MasteryStage) -> Bool {
        lhs.rung < rhs.rung
    }

    var displayName: String {
        switch self {
        case .seen: return "Seen"
        case .recognizes: return "Recognizes"
        case .producesOnPrompt: return "Produces"
        case .usesUnprompted: return "Uses it"
        }
    }

    var symbolName: String {
        switch self {
        case .seen: return "eye"
        case .recognizes: return "checkmark.circle"
        case .producesOnPrompt: return "text.bubble"
        case .usesUnprompted: return "star.fill"
        }
    }
}
