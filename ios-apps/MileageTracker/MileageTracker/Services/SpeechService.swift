import AVFoundation
import Speech
import Observation

/// Handles both text-to-speech (the app talks) and speech recognition (the user talks).
/// This powers the voice-first trip logging flow where the app asks questions
/// and the user responds verbally.
@Observable
class SpeechService {
    // MARK: - State

    var isListening = false
    var recognizedText = ""
    var isAvailable = false

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    init() {
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    // MARK: - Text-to-Speech (App Talks)

    /// Speak text aloud. Interrupts any current speech.
    func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    /// Speak text and call completion when done speaking.
    func speak(_ text: String, completion: @escaping () -> Void) {
        speak(text)
        // Estimate speech duration: ~150 words per minute, avg 5 chars per word
        let wordCount = Double(text.split(separator: " ").count)
        let duration = max(1.0, wordCount / 2.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            completion()
        }
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Speech Recognition (User Talks)

    /// Request microphone and speech recognition permissions.
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        let audioStatus = await AVAudioApplication.requestRecordPermission()
        return audioStatus
    }

    /// Start listening for speech input. Updates `recognizedText` as the user speaks.
    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        // Cancel any existing recognition
        stopListening()

        recognizedText = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition for privacy and speed
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.recognizedText = result.bestTranscription.formattedString
            }

            if error != nil || (result?.isFinal ?? false) {
                self.stopListening()
            }
        }
    }

    /// Stop listening and clean up audio resources.
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    // MARK: - Audio Session

    /// Configure audio session for both TTS output and speech recognition input.
    func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
            )
            try session.setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }

    func deactivateAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }
}
