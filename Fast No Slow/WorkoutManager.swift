import Foundation
import HealthKit
import CoreLocation
import CoreMotion
import AVFoundation
import Combine

class WorkoutManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    // MARK: - Published Properties
    @Published var heartRate: Double = 0
    @Published var timeInZone: TimeInterval = 0
    @Published var distanceInZone: Double = 0 // meters
    @Published var totalDistance: Double = 0
    @Published var currentElevation: Double = 0
    @Published var elevationGain: Double = 0
    @Published var elevationLoss: Double = 0
    @Published var isInZone: Bool = false
    @Published var isWorkoutActive: Bool = false
    @Published var zoneStatus: ZoneStatus = .belowZone
    @Published var elapsedTime: TimeInterval = 0
    @Published var cadence: Int? = nil // steps per minute, nil = no data / not walking

    // MARK: - Settings
    var lowHR: Int = 120
    var highHR: Int = 160
    var metronomeEnabled: Bool = false
    var metronomeBPM: Int = 170

    // MARK: - Private
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var lastInZoneLocation: CLLocation?
    private var timer: Timer?
    private var startDate: Date?
    private var previousElevation: Double?
    private let synthesizer = AVSpeechSynthesizer()
    private var lastPromptTime: Date = .distantPast
    private let promptCooldown: TimeInterval = 15 // seconds between voice prompts

    // MARK: - Pedometer
    private let pedometer = CMPedometer()
    private var cadenceTimer: Timer?
    private var recentStepCounts: [(steps: Int, duration: TimeInterval)] = []

    // MARK: - HR Source Tracking
    private var currentHRSource: HRSource = .none
    private var hrTimeoutTimer: Timer?
    private let hrTimeoutInterval: TimeInterval = 10

    // MARK: - Metronome
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var metronomeTimer: Timer?
    private var clickBuffer: AVAudioPCMBuffer?

    enum ZoneStatus: String {
        case belowZone = "SPEED UP"
        case inZone = "IN THE ZONE"
        case aboveZone = "SLOW DOWN"
    }

    private enum HRSource {
        case none
        case appleWatch
        case bluetoothStrap
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
    }

    // MARK: - Authorization
    func requestAuthorization() {
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
        let typesToWrite: Set<HKSampleType> = [
            HKSampleType.workoutType()
        ]

        healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead) { success, error in
            if let error = error {
                print("HealthKit auth error: \(error.localizedDescription)")
            }
        }

        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Workout Control
    func startWorkout() {
        startDate = Date()
        isWorkoutActive = true
        heartRate = 0
        timeInZone = 0
        distanceInZone = 0
        totalDistance = 0
        elevationGain = 0
        elevationLoss = 0
        elapsedTime = 0
        previousElevation = nil
        lastLocation = nil
        lastInZoneLocation = nil

        cadence = nil
        recentStepCounts = []
        currentHRSource = .none
        hrTimeoutTimer?.invalidate()
        hrTimeoutTimer = nil

        startHeartRateQuery()
        locationManager.startUpdatingLocation()
        startCadenceUpdates()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.startDate ?? Date())
            if self.isInZone {
                self.timeInZone += 1
            }
        }

        if metronomeEnabled {
            startMetronome()
        }

        speak("Workout started. Target zone: \(lowHR) to \(highHR) beats per minute.")
    }

    func stopWorkout() {
        isWorkoutActive = false
        heartRateQuery = nil
        timer?.invalidate()
        timer = nil
        cadenceTimer?.invalidate()
        cadenceTimer = nil
        hrTimeoutTimer?.invalidate()
        hrTimeoutTimer = nil
        pedometer.stopUpdates()
        locationManager.stopUpdatingLocation()
        stopMetronome()

        let minutes = Int(timeInZone) / 60
        let seconds = Int(timeInZone) % 60
        let distanceMiles = distanceInZone * 0.000621371
        var summary = "Workout complete. You spent \(minutes) minutes and \(seconds) seconds in your zone, covering \(String(format: "%.1f", distanceMiles)) miles."
        if let cadence = cadence {
            summary += " Average cadence: \(cadence) steps per minute."
        }
        speak(summary)
    }

    // MARK: - Cadence (Pedometer)
    private func startCadenceUpdates() {
        guard CMPedometer.isStepCountingAvailable() else { return }

        // Query pedometer every 5 seconds for a rolling window
        cadenceTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isWorkoutActive else { return }
            let now = Date()
            let windowStart = now.addingTimeInterval(-5.0)
            self.pedometer.queryPedometerData(from: windowStart, to: now) { data, error in
                DispatchQueue.main.async {
                    guard let data = data else {
                        self.cadence = nil
                        return
                    }
                    let steps = data.numberOfSteps.intValue
                    let duration = data.endDate.timeIntervalSince(data.startDate)

                    // Keep last 3 samples (15s rolling window) for smoothing
                    self.recentStepCounts.append((steps: steps, duration: duration))
                    if self.recentStepCounts.count > 3 {
                        self.recentStepCounts.removeFirst()
                    }

                    let totalSteps = self.recentStepCounts.reduce(0) { $0 + $1.steps }
                    let totalDuration = self.recentStepCounts.reduce(0.0) { $0 + $1.duration }

                    if totalSteps == 0 || totalDuration < 1 {
                        self.cadence = nil
                    } else {
                        self.cadence = Int(round(Double(totalSteps) / totalDuration * 60.0))
                    }
                }
            }
        }
    }

    // MARK: - Metronome
    private func startMetronome() {
        configureAudioSession()

        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let sampleRate: Double = 44100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        engine.connect(player, to: engine.mainMixerNode, format: format)

        // Generate click buffer: ~30ms 880Hz sine wave with exponential decay
        let duration: Double = 0.03
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        buffer.frameLength = frameCount

        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<Int(frameCount) {
                let t = Double(i) / sampleRate
                let sine = sin(2.0 * .pi * 880.0 * t)
                let envelope = exp(-t * 100.0) // fast decay
                channelData[i] = Float(sine * envelope * 0.5)
            }
        }

        self.audioEngine = engine
        self.playerNode = player
        self.clickBuffer = buffer

        do {
            try engine.start()
            player.play()
        } catch {
            print("Metronome audio engine error: \(error.localizedDescription)")
            return
        }

        // Schedule repeating ticks
        let interval = 60.0 / Double(metronomeBPM)
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.playerNode, let buffer = self.clickBuffer else { return }
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
        // Play first tick immediately
        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    private func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        clickBuffer = nil
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {
            print("Audio session error: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Heart Rate Monitoring
    private func startHeartRateQuery() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate),
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples)
        }

        heartRateQuery = query
        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKSample]?) {
        guard let samples = samples as? [HKQuantitySample], let latest = samples.last else { return }

        let hr = latest.quantity.doubleValue(for: HKUnit(from: "count/min"))
        let newSource = detectHRSource(from: latest)

        DispatchQueue.main.async {
            self.heartRate = hr
            self.handleHRSourceChange(newSource: newSource)
            self.updateZoneStatus()
        }
    }

    private func detectHRSource(from sample: HKQuantitySample) -> HRSource {
        // Apple Watch HR data comes from a com.apple bundle (e.g. com.apple.health)
        // Bluetooth chest straps appear as third-party sources
        let bundleID = sample.sourceRevision.source.bundleIdentifier
        if bundleID.hasPrefix("com.apple") {
            return .appleWatch
        } else {
            return .bluetoothStrap
        }
    }

    private func handleHRSourceChange(newSource: HRSource) {
        // Cancel any pending disconnection timeout since a new sample just arrived
        hrTimeoutTimer?.invalidate()
        hrTimeoutTimer = nil

        guard newSource != currentHRSource else {
            // Still on strap — reset the disconnection timeout
            if newSource == .bluetoothStrap {
                scheduleHRDisconnectTimeout()
            }
            return
        }

        let previous = currentHRSource
        currentHRSource = newSource

        switch newSource {
        case .bluetoothStrap:
            speak("Chest strap connected.")
            scheduleHRDisconnectTimeout()
        case .appleWatch:
            // Only announce fallback when switching away from a strap
            if previous == .bluetoothStrap {
                speak("Switching to Apple Watch heart rate.")
            }
        case .none:
            break
        }
    }

    // Starts a timer that fires if no strap sample arrives within hrTimeoutInterval.
    // This detects strap disconnection when there is no Apple Watch fallback,
    // because HealthKit stops delivering samples entirely in that case.
    private func scheduleHRDisconnectTimeout() {
        hrTimeoutTimer?.invalidate()
        hrTimeoutTimer = Timer.scheduledTimer(withTimeInterval: hrTimeoutInterval, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.currentHRSource == .bluetoothStrap {
                    self.currentHRSource = .none
                    self.speak("Heart rate monitor disconnected.")
                }
            }
        }
    }

    private func updateZoneStatus() {
        let previousStatus = zoneStatus

        if heartRate < Double(lowHR) {
            zoneStatus = .belowZone
            isInZone = false
        } else if heartRate > Double(highHR) {
            zoneStatus = .aboveZone
            isInZone = false
        } else {
            zoneStatus = .inZone
            isInZone = true
            lastInZoneLocation = lastLocation
        }

        // Voice prompt on zone change
        if zoneStatus != previousStatus {
            let now = Date()
            if now.timeIntervalSince(lastPromptTime) > promptCooldown {
                lastPromptTime = now
                switch zoneStatus {
                case .belowZone:
                    speak("Heart rate \(Int(heartRate)). Speed up.")
                case .aboveZone:
                    speak("Heart rate \(Int(heartRate)). Slow down.")
                case .inZone:
                    speak("You're in the zone.")
                }
            }
        }
    }

    // MARK: - Location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isWorkoutActive else { return }

        // Distance
        if let last = lastLocation {
            let delta = location.distance(from: last)
            totalDistance += delta
            if isInZone {
                distanceInZone += delta
            }
        }

        // Elevation
        currentElevation = location.altitude
        if let prev = previousElevation {
            let elevDelta = location.altitude - prev
            if elevDelta > 0.5 {
                elevationGain += elevDelta
            } else if elevDelta < -0.5 {
                elevationLoss += abs(elevDelta)
            }
        }
        previousElevation = location.altitude
        lastLocation = location
    }

    // MARK: - Speech
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
