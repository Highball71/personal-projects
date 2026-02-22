import AVFoundation
import Speech
import Observation
import UIKit

/// Handles both text-to-speech (the app talks) and speech recognition (the user talks).
/// This powers the voice-first trip logging flow where the app asks questions
/// and the user responds verbally.
///
/// Key features:
/// - Smart silence timer that resets on each new partial result
/// - Haptic pulse when new speech is detected
/// - Keyword detection ("done", "save", "yes", "no")
/// - Delegate-based TTS completion (no guessing duration)
/// - Configurable minimum-length validation before auto-stopping
@Observable
class SpeechService: NSObject {
    // MARK: - State

    var isListening = false
    var recognizedText = ""
    var isSpeaking = false
    var isAvailable = false

    // MARK: - Callbacks

    /// Called when the silence timer fires and listening auto-stops.
    /// The caller gets the final recognized text.
    var onListeningStopped: ((String) -> Void)?

    /// Called each time a new partial result arrives (for UI updates, haptics, etc.)
    var onPartialResult: ((String) -> Void)?

    /// Called when a trigger keyword is detected ("done", "save", "yes", "no").
    var onKeywordDetected: ((String) -> Void)?

    // MARK: - Configuration

    /// How long to wait after the last partial result before auto-stopping.
    /// Default is 4 seconds — generous enough for pauses between digits.
    var silenceTimeout: TimeInterval = 4.0

    /// Minimum character count required before the silence timer is allowed to stop.
    /// If the recognized text is shorter than this, keep listening even past the timeout.
    /// Set to 0 to disable. Useful for odometer readings (set to 4).
    var minimumLength: Int = 0

    /// Keywords that trigger immediate stop + callback.
    /// Checked case-insensitively against the latest partial result.
    private let triggerKeywords = ["done", "save", "yes", "no", "correct", "cancel"]

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private var speechCompletionHandler: (() -> Void)?
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    /// Location names to provide as contextual strings for better recognition.
    var contextualStrings: [String] = []

    override init() {
        super.init()
        isAvailable = speechRecognizer?.isAvailable ?? false
        synthesizer.delegate = self
        hapticGenerator.prepare()
    }

    // MARK: - Text-to-Speech (App Talks)

    /// Speak text aloud. Interrupts any current speech.
    /// Always stops the mic first to prevent TTS feedback loop.
    func speak(_ text: String) {
        // Kill the mic BEFORE speaking so TTS audio doesn't feed back
        if isListening {
            stopListening()
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        isSpeaking = true
        speechCompletionHandler = nil
        synthesizer.speak(utterance)
    }

    /// Speak text and call completion when done speaking.
    /// Uses AVSpeechSynthesizerDelegate for accurate timing.
    /// Always stops the mic first to prevent TTS feedback loop.
    /// Adds a brief delay after TTS finishes before calling completion,
    /// so any residual speaker audio dissipates before the mic restarts.
    func speak(_ text: String, completion: @escaping () -> Void) {
        // Kill the mic BEFORE speaking so TTS audio doesn't feed back
        if isListening {
            stopListening()
        }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.05
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        isSpeaking = true
        // Wrap the completion with a small delay so speaker audio dissipates
        speechCompletionHandler = {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                completion()
            }
        }
        synthesizer.speak(utterance)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        speechCompletionHandler = nil
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
    ///
    /// The silence timer resets every time a new partial result arrives.
    /// When silence exceeds `silenceTimeout`, listening auto-stops and
    /// `onListeningStopped` is called with the final text.
    ///
    /// - Parameter taskHint: The speech recognition task hint. Use `.dictation` for
    ///   free-form text, `.confirmation` for yes/no, `.search` for short phrases.
    func startListening(taskHint: SFSpeechRecognitionTaskHint = .dictation) {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        // Cancel any existing recognition
        stopListening()

        recognizedText = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = taskHint

        // Prefer on-device recognition for privacy and speed
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        // Provide contextual strings (location names, etc.) to improve accuracy
        if !contextualStrings.isEmpty {
            request.contextualStrings = contextualStrings
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
            resetSilenceTimer()
        } catch {
            print("Audio engine failed to start: \(error)")
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                let text = result.bestTranscription.formattedString
                let previousText = self.recognizedText
                self.recognizedText = text

                // Only fire haptic + callback if text actually changed
                if text != previousText && !text.isEmpty {
                    self.hapticGenerator.impactOccurred()
                    self.onPartialResult?(text)
                    self.resetSilenceTimer()

                    // Check for trigger keywords in the latest segment
                    self.checkForKeywords(in: text)
                }

                if result.isFinal {
                    self.finishListening()
                }
            }

            if let error {
                // Don't treat cancellation as a real error
                let nsError = error as NSError
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 209 {
                    // "Retry" — the recognition request was cancelled, which we do intentionally
                    return
                }
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 203 {
                    // No speech detected — that's fine, silence timer handles it
                    self.finishListening()
                    return
                }
                print("Speech recognition error: \(error)")
                self.finishListening()
            }
        }
    }

    /// Stop listening and clean up audio resources.
    /// Does NOT fire the onListeningStopped callback — use this for manual cancellation.
    func stopListening() {
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
    }

    /// Stop listening and fire the callback with the final text.
    /// Called by the silence timer or when recognition produces a final result.
    /// Guarded by `isListening` so it only fires the callback once — the silence
    /// timer and recognition callback can both try to call this.
    private func finishListening() {
        guard isListening else { return }

        let finalText = recognizedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // If we haven't met the minimum length, keep listening
        if minimumLength > 0 {
            let digitsOnly = finalText.filter { $0.isNumber }
            if digitsOnly.count < minimumLength && isListening {
                // Reset timer and keep going — not enough digits yet
                resetSilenceTimer()
                return
            }
        }

        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false

        onListeningStopped?(finalText)
    }

    // MARK: - Silence Timer

    /// Reset the silence timer. Called each time a new partial result arrives.
    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self, self.isListening else { return }
            self.finishListening()
        }
    }

    // MARK: - Keyword Detection

    /// Check if the latest recognized text ends with a trigger keyword.
    private func checkForKeywords(in text: String) {
        let words = text.lowercased().split(separator: " ")
        guard let lastWord = words.last else { return }
        let word = String(lastWord)
        if triggerKeywords.contains(word) {
            onKeywordDetected?(word)
        }
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

// MARK: - AVSpeechSynthesizerDelegate

extension SpeechService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            let handler = self.speechCompletionHandler
            self.speechCompletionHandler = nil
            handler?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.isSpeaking = false
            self?.speechCompletionHandler = nil
        }
    }
}
