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

    /// The lesson beat, in order (phase-2 decision 1):
    /// scene → beat of silence → word → definition → neighbour distinction.
    /// The short pauses after word and definition keep their neighbour's
    /// phase — only the big gap after the scene gets its own.
    enum Phase {
        case idle
        case speakingScene
        case beatOfSilence
        case speakingWord
        case speakingDefinition
        case speakingNeighbor
        case finished
    }

    private(set) var phase: Phase = .idle {
        didSet { phaseHandler?(phase) }
    }

    /// Lets a wrapper (Narrator) mirror phase changes without SwiftUI observation.
    var phaseHandler: ((Phase) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private let profile = VoiceProfile.current

    /// The gap that lets the user feel the missing word, in seconds.
    private let beatDuration: TimeInterval = 1.6
    /// The smaller breaths after the word and after the definition.
    private let shortPause: TimeInterval = 0.8

    // Utterance identity → phase mapping for the delegate
    private var sceneUtterance: AVSpeechUtterance?
    private var wordUtterance: AVSpeechUtterance?
    private var definitionUtterance: AVSpeechUtterance?
    private var neighborUtterance: AVSpeechUtterance?
    private var finalUtterance: AVSpeechUtterance?

    override init() {
        super.init()
        synthesizer.delegate = self
        // Spoken audio should play even with the ring switch on silent —
        // the user deliberately started a listening exercise.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    }

    /// Speaks the full lesson beat for one word:
    /// scene, pause, word, pause, definition, pause, neighbour line.
    func speakLesson(for word: SeedWord) {
        stop()

        let sceneUtt = profile.utterance(for: word.systemScene, style: .scene)
        // postUtteranceDelay creates each gap without a timer — it begins
        // only when the utterance actually completes
        sceneUtt.postUtteranceDelay = beatDuration

        let wordUtt = profile.utterance(for: word.word, style: .word)
        wordUtt.preUtteranceDelay = 0.1
        wordUtt.postUtteranceDelay = shortPause

        let defUtt = profile.utterance(for: word.definition, style: .scene)

        var utterances = [sceneUtt, wordUtt, defUtt]
        if let neighborLine = word.spokenNeighborLine {
            defUtt.postUtteranceDelay = shortPause
            let neighborUtt = profile.utterance(for: neighborLine, style: .scene)
            neighborUtterance = neighborUtt
            utterances.append(neighborUtt)
        }

        sceneUtterance = sceneUtt
        wordUtterance = wordUtt
        definitionUtterance = defUtt
        finalUtterance = utterances.last
        phase = .speakingScene
        utterances.forEach { synthesizer.speak($0) }
    }

    /// Speaks a single piece of text (scene replay in reviews, word replay on cards).
    func speak(_ text: String, slowly: Bool = false) {
        stop()
        let utt = profile.utterance(for: text, style: slowly ? .word : .scene)
        finalUtterance = utt // single utterance: ends in .finished
        phase = .speakingWord
        synthesizer.speak(utt)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        sceneUtterance = nil
        wordUtterance = nil
        definitionUtterance = nil
        neighborUtterance = nil
        finalUtterance = nil
        phase = .idle
    }

    // MARK: - AVSpeechSynthesizerDelegate
    // Delegate callbacks arrive on an arbitrary queue; hop to the main actor
    // before touching observable state.

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance === self.wordUtterance {
                self.phase = .speakingWord
            } else if utterance === self.definitionUtterance {
                self.phase = .speakingDefinition
            } else if utterance === self.neighborUtterance {
                self.phase = .speakingNeighbor
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if utterance === self.sceneUtterance {
                self.phase = .beatOfSilence
            }
            if utterance === self.finalUtterance {
                self.phase = .finished
            }
        }
    }
}
