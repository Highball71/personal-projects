import Foundation
import AVFoundation

/// Which voice and speaking rates the app uses, everywhere — live speech and
/// file generation alike. One profile, so regenerating audio after a voice
/// change is detected by the manifest (the profile is part of each asset's
/// fingerprint).
///
/// Voice policy (David, 2026-09-05): prefer the highest-quality Australian
/// English voice on the device — he has downloaded an en-AU Premium voice.
/// Rates are absolute AVSpeechUtterance rates (default is 0.5); David asked
/// for ~0.42–0.45.
struct VoiceProfile {
    let voice: AVSpeechSynthesisVoice?
    let sceneRate: Float
    let wordRate: Float

    /// Stable string identifying voice + rates, mixed into asset fingerprints
    /// so changing the voice or rate invalidates previously generated audio.
    var fingerprint: String {
        "\(voice?.identifier ?? "system-default")|\(sceneRate)|\(wordRate)"
    }

    /// The profile the whole app uses. Recomputed at launch, so a voice
    /// downloaded in Settings gets picked up next start.
    static let current: VoiceProfile = VoiceProfile(
        voice: bestVoice(),
        sceneRate: 0.44,
        wordRate: 0.42
    )

    /// Highest-quality en-AU voice available, falling back gracefully:
    /// en-AU premium → en-AU enhanced → any en-AU → best any-English → system default.
    static func bestVoice() -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()

        func best(in voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
            // Quality raw values order: default < enhanced < premium
            voices.max { $0.quality.rawValue < $1.quality.rawValue }
        }

        let australian = all.filter { $0.language == "en-AU" }
        if let auBest = best(in: australian), auBest.quality != .default {
            return auBest
        }
        if let auAny = australian.first {
            return auAny
        }
        let english = all.filter { $0.language.hasPrefix("en-") }
        if let enBest = best(in: english), enBest.quality != .default {
            return enBest
        }
        return AVSpeechSynthesisVoice(language: "en-AU") ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    /// How a piece of text should be spoken.
    enum Style {
        case scene  // narrative pace
        case word   // slightly slower — the answer landing

        func rate(in profile: VoiceProfile) -> Float {
            switch self {
            case .scene: return profile.sceneRate
            case .word: return profile.wordRate
            }
        }
    }

    /// Builds a configured utterance — the single place utterance settings live.
    func utterance(for text: String, style: Style) -> AVSpeechUtterance {
        let utt = AVSpeechUtterance(string: text)
        utt.voice = voice
        utt.rate = style.rate(in: self)
        return utt
    }
}
