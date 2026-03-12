import AVFoundation

// Metronome modes available on the Start Run screen.
enum MetronomeMode: String, CaseIterable, Identifiable {
    case continuous = "Continuous"
    case guardrail = "Guardrail"
    case fade      = "Fade"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .continuous: return "Always on"
        case .guardrail:  return "Silent when on cadence"
        case .fade:       return "Fades out over 5 min"
        }
    }
}

// Generates a metronome click at the target cadence.
// Uses AVAudioEngine for sample-accurate timing and volume control.
class MetronomeEngine {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?
    private var timer: DispatchSourceTimer?

    private(set) var mode: MetronomeMode = .continuous
    private(set) var targetBPM: Double = 170
    private(set) var isRunning = false

    // Fade mode timing
    private var startTime: Date?
    private let fadeFullDuration: TimeInterval = 180    // 3 min at full volume
    private let fadeOutDuration: TimeInterval = 120     // 2 min fade-out
    // After fadeFullDuration + fadeOutDuration = 5 min, switches to guardrail behavior

    // Guardrail: current cadence, updated externally
    private var currentCadence: Double = 0
    private let cadenceTolerance: Double = 10 // ±10 SPM = "on cadence"

    // MARK: - Public API

    func start(mode: MetronomeMode, targetBPM: Double) {
        stop()

        self.mode = mode
        self.targetBPM = targetBPM
        self.startTime = Date()
        self.isRunning = true

        setupAudioEngine()
        generateClickBuffer()
        startClickTimer()
    }

    func stop() {
        isRunning = false
        timer?.cancel()
        timer = nil
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }

    /// Call frequently with the runner's current cadence so guardrail/fade
    /// modes know whether to play or stay silent.
    func updateCadence(_ cadence: Double) {
        currentCadence = cadence
    }

    /// Change target BPM while running (e.g., if user changes setting).
    func updateTargetBPM(_ bpm: Double) {
        guard bpm != targetBPM else { return }
        targetBPM = bpm
        if isRunning {
            // Restart timer with new interval
            startClickTimer()
        }
    }

    // MARK: - Audio Setup

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)
        engine.connect(player, to: mixer, format: format)

        do {
            // Configure audio session to mix with speech and play in background.
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            try engine.start()
            player.play()
        } catch {
            print("MetronomeEngine: audio engine error — \(error.localizedDescription)")
        }

        audioEngine = engine
        playerNode = player
    }

    /// Generate a short click sound — a 15ms sine burst with quick fade-out.
    private func generateClickBuffer() {
        guard let engine = audioEngine else { return }
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let duration = 0.015 // 15ms click
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        // Fill with a 1000 Hz sine wave that fades out quickly.
        let channels = Int(format.channelCount)
        for ch in 0..<channels {
            guard let channelData = buffer.floatChannelData?[ch] else { continue }
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let sine = sin(2.0 * .pi * 1000.0 * t)
                // Quick exponential fade-out
                let envelope = exp(-t * 300.0)
                channelData[i] = Float(sine * envelope * 0.5)
            }
        }

        clickBuffer = buffer
    }

    // MARK: - Timer & Playback

    private func startClickTimer() {
        timer?.cancel()

        guard targetBPM > 0 else { return }
        let interval = 60.0 / targetBPM // seconds per beat

        let source = DispatchSource.makeTimerSource(queue: .global(qos: .userInteractive))
        source.schedule(
            deadline: .now(),
            repeating: interval,
            leeway: .milliseconds(1)
        )
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    private func tick() {
        guard isRunning, let player = playerNode, let buffer = clickBuffer else { return }

        let volume = computeVolume()
        player.volume = volume

        if volume > 0.01 {
            // Schedule the click buffer for immediate playback
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }

    /// Compute current volume based on mode, elapsed time, and cadence.
    private func computeVolume() -> Float {
        switch mode {
        case .continuous:
            return 0.8

        case .guardrail:
            return guardrailVolume()

        case .fade:
            guard let start = startTime else { return 0.8 }
            let elapsed = Date().timeIntervalSince(start)

            if elapsed < fadeFullDuration {
                // Phase 1: full volume
                return 0.8
            } else if elapsed < fadeFullDuration + fadeOutDuration {
                // Phase 2: linear fade from 0.8 to 0
                let fadeProgress = (elapsed - fadeFullDuration) / fadeOutDuration
                let faded = Float(0.8 * (1.0 - fadeProgress))
                // But blend with guardrail — if cadence drops, bring volume back
                return max(faded, guardrailVolume())
            } else {
                // Phase 3: pure guardrail
                return guardrailVolume()
            }
        }
    }

    /// Volume for guardrail mode: silent when on cadence, fades in when off.
    private func guardrailVolume() -> Float {
        guard currentCadence > 0 else { return 0.8 } // no data yet, play
        let deviation = abs(currentCadence - targetBPM)
        if deviation <= cadenceTolerance {
            return 0.0 // on cadence, stay silent
        }
        // Linear ramp from 0 at tolerance edge to 0.8 at tolerance + 20
        let ramp = min(Float((deviation - cadenceTolerance) / 20.0), 1.0)
        return ramp * 0.8
    }
}
