import Foundation
import AVFoundation

/// Live speech synthesis — the always-available fallback behind Narrator.
/// Views should talk to Narrator, which prefers generated audio files and
/// drops down to this when a file isn't ready yet.
///
/// Speaks with the app-wide VoiceProfile (best downloaded en-AU voice,
/// rates ~0.42–0.45), so live speech and generated files sound the same.
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {

    enum Phase {
        case idle
        case speakingScene
        case beatOfSilence
        case speakingWord
        case finished
    }

    private(set) var phase: Phase = .idle {
        didSet { phaseHandler?(phase) }
    }

    /// Lets a wrapper (Narrator) mirror phase changes without SwiftUI observation.
    var phaseHandler: ((Phase) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private let profile = VoiceProfile.current

    /// How long the gap breathes between scene and word, in seconds.
    private let beatDuration: TimeInterval = 1.6

    /// Set when speaking so the delegate can tell scene and word utterances apart.
    private var sceneUtterance: AVSpeechUtterance?
    private var wordUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
        // Spoken audio should play even with the ring switch on silent —
        // the user deliberately started a listening exercise.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    /// Speaks the full lesson beat for one word: scene, pause, word.
    func speakLesson(scene: String, word: String) {
        stop()

        let sceneUtt = profile.utterance(for: scene, style: .scene)
        // postUtteranceDelay creates the beat of silence without a timer —
        // it begins only when the scene utterance actually completes
        sceneUtt.postUtteranceDelay = beatDuration

        let wordUtt = profile.utterance(for: word, style: .word)
        wordUtt.preUtteranceDelay = 0.1

        sceneUtterance = sceneUtt
        wordUtterance = wordUtt
        phase = .speakingScene
        synthesizer.speak(sceneUtt)
        synthesizer.speak(wordUtt)
    }

    /// Speaks a single piece of text (scene replay in reviews, word replay on cards).
    func speak(_ text: String, slowly: Bool = false) {
        stop()
        let utt = profile.utterance(for: text, style: slowly ? .word : .scene)
        sceneUtterance = nil
        wordUtterance = utt // treat as "word" so phase ends in .finished
        phase = .speakingWord
        synthesizer.speak(utt)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        sceneUtterance = nil
        wordUtterance = nil
        phase = .idle
    }

    // MARK: - AVSpeechSynthesizerDelegate
    // Delegate callbacks arrive on an arbitrary queue; hop to the main actor
    // before touching observable state.

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance === self.sceneUtterance {
                self.phase = .beatOfSilence
            } else if utterance === self.wordUtterance {
                self.phase = .finished
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance === self.wordUtterance {
                self.phase = .speakingWord
            }
        }
    }
}
