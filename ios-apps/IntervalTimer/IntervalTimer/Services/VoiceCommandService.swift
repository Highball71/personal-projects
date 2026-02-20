import Speech
import AVFoundation

/// Listens for voice commands ("pause", "resume", "stop") using on-device
/// speech recognition. Runs only in the foreground when the user opts in.
@Observable
class VoiceCommandService {
    var isListening = false
    var isAvailable = false

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    /// Called when a recognized command is detected
    var onCommand: ((VoiceCommand) -> Void)?

    enum VoiceCommand {
        case pause
        case resume
        case stop
    }

    init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        isAvailable = speechRecognizer?.isAvailable ?? false
    }

    /// Request both speech recognition and microphone permissions.
    /// Returns true only if both are authorized.
    func requestPermissions() async -> Bool {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else { return false }

        // Microphone permission is requested automatically when we start
        // the audio engine, but we can check the current status
        let audioStatus = AVAudioApplication.shared.recordPermission
        if audioStatus == .undetermined {
            let granted = await AVAudioApplication.requestRecordPermission()
            return granted
        }
        return audioStatus == .granted
    }

    /// Start listening for voice commands.
    /// Call this after permissions are granted and audio session is configured.
    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        // Clean up any previous session
        stopListening()

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else { return }

        // Use on-device recognition for privacy and low latency
        recognitionRequest.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            recognitionRequest.requiresOnDeviceRecognition = true
        }

        // Tap into the audio engine's input to feed the recognizer
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Track the last processed text length to avoid re-processing
        var lastProcessedLength = 0

        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self, let result else {
                if error != nil {
                    self?.restartListening()
                }
                return
            }

            let text = result.bestTranscription.formattedString.lowercased()

            // Only look at new text since last check
            let newText = String(text.dropFirst(lastProcessedLength))
            lastProcessedLength = text.count

            if newText.contains("pause") {
                self.onCommand?(.pause)
            } else if newText.contains("resume") || newText.contains("continue") {
                self.onCommand?(.resume)
            } else if newText.contains("stop") {
                self.onCommand?(.stop)
            }

            // Recognition tasks time out — restart when final result arrives
            if result.isFinal {
                self.restartListening()
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
        } catch {
            print("Voice command audio engine failed to start: \(error)")
        }
    }

    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    /// Restart recognition after a timeout or final result
    private func restartListening() {
        stopListening()
        // Small delay to avoid rapid restart loops
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.startListening()
        }
    }
}
