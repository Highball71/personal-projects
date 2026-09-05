import Foundation
import AVFoundation

/// The single voice of the app. Views talk to Narrator; Narrator decides
/// whether a request plays from generated audio files (preferred) or falls
/// back to live AVSpeech synthesis (always available).
///
/// The lesson beat (phase-2 decision 1) — scene → gap → word → definition →
/// neighbour distinction — is completion-driven in both paths: every gap
/// starts when the previous audio actually finishes (file completion
/// callback, or utterance didFinish), never from a guessed duration. The
/// visual keys off `phase`, so each element of the card can land exactly
/// when it is heard, regardless of which path produced the sound.
@Observable
final class Narrator: NSObject, AVAudioPlayerDelegate {

    /// Mirrors SpeechService.Phase so views can switch on one type.
    private(set) var phase: SpeechService.Phase = .idle

    /// The gap that lets the user feel the missing word, in seconds.
    private let beatDuration: TimeInterval = 1.6
    /// The smaller breaths after the word and after the definition.
    private let shortPause: TimeInterval = 0.8

    /// One step of a file-based playback sequence.
    private struct QueueItem {
        let url: URL
        let phase: SpeechService.Phase
        let gapAfter: TimeInterval
        let gapPhase: SpeechService.Phase?  // phase to show during the gap; nil keeps the current one
    }

    private let live = SpeechService()
    private var player: AVAudioPlayer?
    private var queue: [QueueItem] = []
    private var currentGap: TimeInterval = 0
    private var currentGapPhase: SpeechService.Phase?
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

    /// The full lesson beat for one word. Uses generated files when every
    /// element's asset exists; otherwise live synthesis end to end (mixing
    /// paths would make the pacing inconsistent).
    func speakLesson(for word: SeedWord) {
        stop()
        let gen = generation
        Task { @MainActor in
            let store = AudioStore.shared
            let sceneURL = await store.url(for: .scene(for: word))
            let wordURL = await store.url(for: .word(for: word))
            let defURL = await store.url(for: .definition(for: word))
            var neighborURL: URL?
            if let neighborAsset = AudioStore.AssetRequest.neighborLine(for: word) {
                neighborURL = await store.url(for: neighborAsset)
            }
            guard gen == self.generation else { return } // stopped while resolving

            let neighborReady = word.spokenNeighborLine == nil || neighborURL != nil
            if let sceneURL, let wordURL, let defURL, neighborReady {
                var items = [
                    QueueItem(url: sceneURL, phase: .speakingScene, gapAfter: self.beatDuration, gapPhase: .beatOfSilence),
                    QueueItem(url: wordURL, phase: .speakingWord, gapAfter: self.shortPause, gapPhase: nil),
                    QueueItem(url: defURL, phase: .speakingDefinition, gapAfter: self.shortPause, gapPhase: nil),
                ]
                if let neighborURL {
                    items.append(QueueItem(url: neighborURL, phase: .speakingNeighbor, gapAfter: 0, gapPhase: nil))
                }
                self.queue = items
                self.playNext()
            } else {
                self.live.speakLesson(for: word)
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
                self.queue = [QueueItem(url: url, phase: .speakingWord, gapAfter: 0, gapPhase: nil)]
                self.playNext()
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
        queue = []
        live.stop()
        phase = .idle
    }

    // MARK: - File playback

    private func playNext() {
        guard !queue.isEmpty else {
            phase = .finished
            return
        }
        let item = queue.removeFirst()
        do {
            let p = try AVAudioPlayer(contentsOf: item.url)
            p.delegate = self
            player = p
            currentGap = item.gapAfter
            currentGapPhase = item.gapPhase
            phase = item.phase
            p.play()
        } catch {
            // Corrupt file mid-sequence: end quietly rather than mixing in
            // live audio with different pacing. The card is on screen anyway.
            queue = []
            phase = .finished
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let gen = generation
        Task { @MainActor in
            guard gen == self.generation else { return }
            guard !self.queue.isEmpty else {
                self.phase = .finished
                return
            }
            let gap = self.currentGap
            if let gapPhase = self.currentGapPhase {
                self.phase = gapPhase
            }
            // Completion-driven gap: we only get here when playback truly ended
            self.beatTask = Task { @MainActor in
                if gap > 0 {
                    try? await Task.sleep(for: .seconds(gap))
                }
                guard !Task.isCancelled, gen == self.generation else { return }
                self.playNext()
            }
        }
    }
}
