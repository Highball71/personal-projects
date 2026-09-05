import Foundation
import AVFoundation

/// A thing that can render spoken audio for a piece of text into a file.
///
/// This is the provider seam: swapping in OpenAI TTS (or any API voice) later
/// means adding ONE new file that conforms to this protocol and returning it
/// from `SpeechAudioGeneratorFactory.make()`. The manifest, store, player,
/// and views never change.
protocol SpeechAudioGenerator {
    /// Identifies the provider in asset fingerprints, so switching providers
    /// invalidates previously generated audio.
    var providerID: String { get }

    /// Renders `text` as spoken audio and writes a playable file to `url`.
    func writeAudio(for text: String, style: VoiceProfile.Style, to url: URL) async throws
}

/// Picks the active generator. This is the one-line change when a new
/// provider arrives (plus its conforming file).
enum SpeechAudioGeneratorFactory {
    static func make() -> SpeechAudioGenerator {
        AVSpeechFileGenerator(profile: .current)
    }
}

/// Generates audio files on-device with AVSpeechSynthesizer — no network, no
/// key. Quality is whatever the best downloaded voice provides (Premium en-AU
/// on David's devices). Output is mono AAC in an .m4a container.
final class AVSpeechFileGenerator: SpeechAudioGenerator {
    let providerID = "avspeech"

    private let profile: VoiceProfile

    init(profile: VoiceProfile) {
        self.profile = profile
    }

    enum GeneratorError: Error {
        case unexpectedBufferType
        case emptyResult
    }

    func writeAudio(for text: String, style: VoiceProfile.Style, to url: URL) async throws {
        // A dedicated synthesizer per render: the shared live one must stay
        // free for actual playback, and write() sessions can't overlap.
        let synthesizer = AVSpeechSynthesizer()
        let utterance = profile.utterance(for: text, style: style)

        var audioFile: AVAudioFile?
        var wroteFrames = false

        // synthesizer.write delivers PCM buffers as they're rendered; a
        // zero-length buffer marks the end of the utterance.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var finished = false
            synthesizer.write(utterance) { buffer in
                guard !finished else { return }
                guard let pcm = buffer as? AVAudioPCMBuffer else {
                    finished = true
                    continuation.resume(throwing: GeneratorError.unexpectedBufferType)
                    return
                }
                if pcm.frameLength == 0 {
                    finished = true
                    continuation.resume()
                    return
                }
                do {
                    if audioFile == nil {
                        // Encode to AAC so 100+ assets stay tens of MB, not hundreds
                        let settings: [String: Any] = [
                            AVFormatIDKey: kAudioFormatMPEG4AAC,
                            AVSampleRateKey: pcm.format.sampleRate,
                            AVNumberOfChannelsKey: 1,
                            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                        ]
                        audioFile = try AVAudioFile(
                            forWriting: url,
                            settings: settings,
                            commonFormat: pcm.format.commonFormat,
                            interleaved: pcm.format.isInterleaved
                        )
                    }
                    try audioFile?.write(from: pcm)
                    wroteFrames = true
                } catch {
                    finished = true
                    continuation.resume(throwing: error)
                }
            }
        }

        guard wroteFrames else { throw GeneratorError.emptyResult }
    }
}
