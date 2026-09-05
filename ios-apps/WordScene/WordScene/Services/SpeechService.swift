import Foundation
import AVFoundation

/// Drives the voice-first learning loop (design decision #7):
/// hear the scene → a beat of silence → hear the word.
///
/// The beat of silence is the whole point: the scene opens a gap, the pause
/// lets the user feel it, and the word arrives to fill it. The UI observes
/// `phase` so the visual reveal can land exactly when the word is spoken.
@Observable
final class SpeechService: NSObject, AVSpeechSynthesizerDelegate {

    enum Phase {
        case idle
        case speakingScene
        case beatOfSilence
        case speakingWord
        case finished
    }

    private(set) var phase: Phase = .idle

    private let synthesizer = AVSpeechSynthesizer()

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

        let sceneUtt = utterance(for: scene)
        // postUtteranceDelay creates the beat of silence without a timer
        sceneUtt.postUtteranceDelay = beatDuration

        let wordUtt = utterance(for: word)
        // The word lands slightly slower and after a breath, like an answer
        wordUtt.rate = AVSpeechUtteranceDefaultSpeechRate * 0.82
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
        let utt = utterance(for: text)
        if slowly { utt.rate = AVSpeechUtteranceDefaultSpeechRate * 0.78 }
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

    private func utterance(for text: String) -> AVSpeechUtterance {
        let utt = AVSpeechUtterance(string: text)
        utt.voice = AVSpeechSynthesisVoice(language: "en-US")
        utt.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        return utt
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
