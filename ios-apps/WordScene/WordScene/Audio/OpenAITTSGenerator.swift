import Foundation

/// OpenAI TTS behind the SpeechAudioGenerator seam.
///
/// How this is actually used (decision, 2026-09-05): the main-track content is
/// fixed, so its audio is generated ONCE by `scripts/generate_bundled_audio.py`
/// (which mirrors this request format exactly) and shipped in Resources/audio/.
/// The app itself never calls the OpenAI API — there is no key on-device, and
/// `SpeechAudioGeneratorFactory` keeps returning the AVSpeech generator, which
/// now only ever runs for content the bundle can't know about (user-authored
/// scenes, future dynamic content).
///
/// This conformer exists so the provider is a real, compiled implementation of
/// the seam: point the factory at it in an environment that has
/// OPENAI_API_KEY (a Mac tool, a server) and everything downstream works
/// unchanged.
final class OpenAITTSGenerator: SpeechAudioGenerator {
    let providerID = "openai-tts"

    static let model = "gpt-4o-mini-tts"

    private let voice: String
    private let apiKey: String

    enum TTSError: Error {
        case missingAPIKey
        case httpError(Int, String)
    }

    /// - Parameters:
    ///   - voice: OpenAI voice name (e.g. "ash", "sage", "onyx").
    ///   - apiKey: taken from the environment by default; never hard-code it.
    init(voice: String, apiKey: String? = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]) throws {
        guard let apiKey, !apiKey.isEmpty else { throw TTSError.missingAPIKey }
        self.voice = voice
        self.apiKey = apiKey
    }

    /// Per-style narration instructions — keep in sync with the probe and
    /// generation scripts so bundled and ad-hoc audio sound identical.
    static func instructions(for style: VoiceProfile.Style) -> String {
        switch style {
        case .scene:
            return "Narrate this second-person scene like a warm, unhurried audiobook narrator. Measured pace, vivid but calm. Do not rush."
        case .word:
            return "Say this single word slowly and clearly, like the satisfying answer to a riddle. Nothing else."
        }
    }

    func writeAudio(for text: String, style: VoiceProfile.Style, to url: URL) async throws {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/audio/speech")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model,
            "voice": voice,
            "input": text,
            "instructions": Self.instructions(for: style),
            "response_format": "mp3",
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TTSError.httpError(http.statusCode, String(data: data.prefix(300), encoding: .utf8) ?? "")
        }
        try data.write(to: url, options: .atomic)
    }
}
