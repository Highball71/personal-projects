import Foundation
import AVFoundation

/// The single voice of the app. Views talk to Narrator; Narrator decides
/// whether a request plays from a generated audio file (preferred) or falls
/// back to live AVSpeech synthesis (always available).
///
/// The lesson beat — scene → gap → word — is completion-driven in both paths:
/// the gap starts when the scene audio actually finishes (file completion
/// callback, or utterance didFinish), never from a guessed duration. The
/// visual reveal keys off `phase` hitting `.speakingWord`, so it lands exactly
/// when the word is heard regardless of which path produced the sound.
@Observable
final class Narrator: NSObject, AVAudioPlayerDelegate {

    /// Mirrors SpeechService.Phase so views can switch on one type.
    private(set) var phase: SpeechService.Phase = .idle

    /// The beat of silence between scene and word, in seconds.
    private let beatDuration: TimeInterval = 1.6

    private let live = SpeechService()
    private var player: AVAudioPlayer?
    private var pendingWordURL: URL?     // set while a file-based lesson is mid-flight
    private var pendingWordText: String? // fallback if the word file is missing
    private var beatTask: Task<Void, Never>?
    private var generation = 0           // invalidates stale callbacks after stop()

    override init() {
        super.init()
        // Forward live-synthesis phases so both paths drive the same UI
        live.phaseHandler = { [weak self] livePhase in
            self?.phase = livePhase
        }
    }

    // MARK: - Public API

    /// The full lesson beat for one word. Uses generated files when both the
    /// scene and word assets exist; otherwise live synthesis end to end
    /// (mixing paths would make the gap timing inconsistent).
    func speakLesson(for word: SeedWord) {
        stop()
        let gen = generation
        Task { @MainActor in
            let sceneURL = await AudioStore.shared.url(for: .scene(for: word))
            let wordURL = await AudioStore.shared.url(for: .word(for: word))
            guard gen == self.generation else { return } // stopped while resolving
            if let sceneURL, let wordURL {
                self.pendingWordURL = wordURL
                self.pendingWordText = word.word
                self.playFile(at: sceneURL, as: .speakingScene)
            } else {
                self.live.speakLesson(scene: word.systemScene, word: word.word)
            }
        }
    }

    /// A single scene or sentence, from file when `asset` resolves, else live.
    func speak(text: String, asset: AudioStore.AssetRequest? = nil, style: VoiceProfile.Style = .scene) {
        stop()
        let gen = generation
        Task { @MainActor in
            if let asset, let url = await AudioStore.shared.url(for: asset) {
                guard gen == self.generation else { return }
                self.playFile(at: url, as: .speakingWord) // single utterance: ends in .finished
            } else {
                guard gen == self.generation else { return }
                self.live.speak(text, slowly: style.rate(in: .current) <= 0.42)
            }
        }
    }

    func stop() {
        generation += 1
        beatTask?.cancel()
        beatTask = nil
        player?.stop()
        player = nil
        pendingWordURL = nil
        pendingWordText = nil
        live.stop()
        phase = .idle
    }

    // MARK: - File playback

    private func playFile(at url: URL, as newPhase: SpeechService.Phase) {
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            player = p
            phase = newPhase
            p.play()
        } catch {
            // Corrupt/missing file: fall back to live for whatever remains
            if newPhase == .speakingScene, let wordText = pendingWordText {
                pendingWordURL = nil
                pendingWordText = nil
                live.speak(wordText, slowly: true)
            } else {
                phase = .idle
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let gen = generation
        Task { @MainActor in
            guard gen == self.generation else { return }
            if let wordURL = self.pendingWordURL {
                // Scene finished → the gap. Completion-driven: we only get
                // here when playback actually ended.
                self.pendingWordURL = nil
                self.phase = .beatOfSilence
                self.beatTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(self.beatDuration))
                    guard !Task.isCancelled, gen == self.generation else { return }
                    self.pendingWordText = nil
                    self.playFile(at: wordURL, as: .speakingWord)
                }
            } else {
                self.phase = .finished
            }
        }
    }
}
