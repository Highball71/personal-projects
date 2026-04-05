import Foundation
import HealthKit
import CoreLocation
import CoreBluetooth
import AVFoundation
import Combine
import ActivityKit

// MARK: - Live Activity Attributes
// NOTE: This struct must be kept in sync with WorkoutActivityAttributes in the
// WorkoutLiveActivity extension. Both targets define an identical copy so that
// ActivityKit can serialize/deserialize across the process boundary.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var heartRate: Int
        var zoneStatus: String   // "ON TRACK", "QUICK FEET", "LIGHTEN UP", "EASE EFFORT"
        var elapsedTime: TimeInterval
        var cadence: Int
        var isPaused: Bool
    }
    var targetLow: Int
    var targetHigh: Int
    var targetCadence: Int
}

class WorkoutManager: NSObject, ObservableObject, CLLocationManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {

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
    @Published var connectedDeviceName: String?
    @Published var hrMonitorState: HRMonitorState = .disconnected

    // HR source, cadence, coaching, compliance
    @Published var hrSource: HRSource = .unknown
    @Published var currentCadence: Double = 0
    @Published var activeCue: CoachingCue = .holdCadence
    @Published var timeOnCadence: TimeInterval = 0
    @Published var showSummary: Bool = false
    @Published var isPaused: Bool = false

    enum HRMonitorState {
        case disconnected
        case searching
        case connected
    }

    enum ZoneStatus: String {
        case belowZone = "SPEED UP"
        case inZone = "IN THE ZONE"
        case aboveZone = "SLOW DOWN"
    }

    // MARK: - Settings (set from ContentView before starting)
    var cadenceTarget = CadenceTarget(target: 170, floor: 164)
    var hrGuardrail = HRGuardrail(low: 120, high: 150)
    var metronomeMode: MetronomeMode = .continuous


    // MARK: - Sub-engines
    let coachingEngine = CoachingEngine()
    let cadenceManager = CadenceManager()
    let metronomeEngine = MetronomeEngine()
    let hapticManager = HapticManager()

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
    // Premium male US English voice — resolved once at init, falls back gracefully.
    private let preferredVoice: AVSpeechSynthesisVoice? = {
        // Try Zach (premium male) first
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.voice.premium.en-US.Zach") {
            return voice
        }
        // Fallback: any premium/enhanced en-US voice
        let enUS = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == "en-US" && $0.quality.rawValue >= AVSpeechSynthesisVoiceQuality.enhanced.rawValue
        }
        return enUS.first ?? AVSpeechSynthesisVoice(language: "en-US")
    }()

    // BLE heart rate monitor
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private let heartRateServiceUUID = CBUUID(string: "180D")
    private let heartRateMeasurementUUID = CBUUID(string: "2A37")

    // HR source tracking
    private var lastBLEHeartRateTime: Date = .distantPast
    private var previousHRSource: HRSource = .unknown
    /// True for one coaching tick after chest strap connects
    private var sensorJustConnected = false
    /// True for one coaching tick after chest strap disconnects
    private var sensorJustDisconnected = false

    // Compliance: continuous minutes with both HR in zone and cadence on target
    private var complianceStreakStart: Date?
    private var lastComplianceRewardTime: Date = .distantPast

    // Pause tracking
    private var pauseStart: Date?
    private var totalPausedTime: TimeInterval = 0

    // Live Activity
    private var liveActivity: Activity<WorkoutActivityAttributes>?

    // Cancellables for cadence observation
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Configure audio session once so metronome + speech survive background
        configureAudioSession()

        // Forward cadence from CadenceManager
        cadenceManager.$currentCadence
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentCadence)
    }

    /// Set up audio session for background playback. Called once at init.
    /// Metronome and speech both use this shared session.
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("Audio session setup error: \(error.localizedDescription)")
        }
    }

    // MARK: - Authorization
    func requestAuthorization() {
        // Log all English voices so we can pick the best one
        logAvailableVoices()

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

        // Request Always so location continues when screen locks
        locationManager.requestAlwaysAuthorization()
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
        timeOnCadence = 0
        previousElevation = nil
        lastLocation = nil
        lastInZoneLocation = nil
        showSummary = false
        isPaused = false
        pauseStart = nil
        totalPausedTime = 0
        complianceStreakStart = nil
        lastComplianceRewardTime = .distantPast

        // Configure coaching engine
        coachingEngine.cadenceTarget = cadenceTarget
        coachingEngine.hrGuardrail = hrGuardrail
        coachingEngine.reset()

        startHeartRateQuery()
        locationManager.startUpdatingLocation()
        cadenceManager.startTracking()

        // Start metronome — 1 beat = 1 step, BPM = cadence target
        metronomeEngine.start(mode: metronomeMode, targetBPM: Double(cadenceTarget.target), cadenceFloor: Double(cadenceTarget.floor))

        // 1-second coaching/tracking timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }

        startLiveActivity()
        speak("Workout started. Target cadence: \(cadenceTarget.target) steps per minute.")
    }

    func stopWorkout() {
        isWorkoutActive = false
        isPaused = false
        heartRateQuery = nil
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        cadenceManager.stopTracking()
        metronomeEngine.stop()
        endLiveActivity()

        let minutes = Int(timeInZone) / 60
        let seconds = Int(timeInZone) % 60
        let distanceMiles = distanceInZone * 0.000621371
        speak("Workout complete. You spent \(minutes) minutes and \(seconds) seconds in your zone, covering \(String(format: "%.1f", distanceMiles)) miles.")

        showSummary = true
    }

    func pauseWorkout() {
        guard isWorkoutActive, !isPaused else { return }
        isPaused = true
        pauseStart = Date()
        timer?.invalidate()
        timer = nil
        metronomeEngine.pause()
        synthesizer.stopSpeaking(at: .word)
        locationManager.stopUpdatingLocation()
        updateLiveActivity()
    }

    /// Apply new settings mid-workout (called from pause editing before resume).
    func applySettings(cadenceTarget: CadenceTarget, hrGuardrail: HRGuardrail) {
        self.cadenceTarget = cadenceTarget
        self.hrGuardrail = hrGuardrail
        coachingEngine.cadenceTarget = cadenceTarget
        coachingEngine.hrGuardrail = hrGuardrail
        metronomeEngine.updateTargetBPM(Double(cadenceTarget.target))
        metronomeEngine.updateCadenceFloor(Double(cadenceTarget.floor))
    }

    func resumeWorkout() {
        guard isWorkoutActive, isPaused else { return }
        if let ps = pauseStart {
            totalPausedTime += Date().timeIntervalSince(ps)
            pauseStart = nil
        }
        isPaused = false
        // Discard last location so we don't count distance covered while paused
        lastLocation = nil
        locationManager.startUpdatingLocation()
        metronomeEngine.resume()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.timerTick()
        }
        updateLiveActivity()
    }

    // MARK: - Heart Rate Monitoring (HealthKit)
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

        // Determine if this sample came from Apple Watch
        // (BLE HR is set directly in peripheral(_:didUpdateValueFor:) and skips this path)
        let isFromBLE = Date().timeIntervalSince(lastBLEHeartRateTime) < 3

        DispatchQueue.main.async {
            // Only use HealthKit HR if BLE is not actively providing data
            if !isFromBLE {
                self.heartRate = hr
                self.hrSource = .appleWatch
                self.coachingEngine.addHeartRate(hr)
            }
            self.updateZoneStatus()
        }
    }

    // MARK: - Zone Status
    private func updateZoneStatus() {
        if heartRate < Double(hrGuardrail.low) {
            zoneStatus = .belowZone
            isInZone = false
        } else if heartRate > Double(hrGuardrail.high) {
            zoneStatus = .aboveZone
            isInZone = false
        } else {
            zoneStatus = .inZone
            isInZone = true
            lastInZoneLocation = lastLocation
        }
    }

    // MARK: - Timer Tick

    private func timerTick() {
        elapsedTime = Date().timeIntervalSince(startDate ?? Date()) - totalPausedTime
        if isInZone { timeInZone += 1 }
        // Cadence compliance: at or above the floor
        if currentCadence > 0 && currentCadence >= Double(cadenceTarget.floor) {
            timeOnCadence += 1
        }
        metronomeEngine.updateCadence(currentCadence)
        runCoaching()
        checkComplianceStreak()
        updateLiveActivity()
    }

    // MARK: - Coaching
    private func runCoaching() {
        let result = coachingEngine.evaluate(
            cadence: currentCadence,
            hrSource: hrSource,
            sensorJustDisconnected: sensorJustDisconnected,
            sensorJustConnected: sensorJustConnected
        )

        // Clear one-shot flags
        sensorJustConnected = false
        sensorJustDisconnected = false

        activeCue = result.cue

        if let message = result.voiceMessage {
            speak(message)
        }
    }

    // MARK: - Compliance Streak (haptic reward)
    private func checkComplianceStreak() {
        let hrOK = isInZone
        let cadenceOK = currentCadence > 0 &&
            currentCadence >= Double(cadenceTarget.floor)

        if hrOK && cadenceOK {
            if complianceStreakStart == nil {
                complianceStreakStart = Date()
            }
            if let start = complianceStreakStart {
                let streak = Date().timeIntervalSince(start)
                // Reward every 5 continuous minutes
                if streak >= 300 &&
                    Date().timeIntervalSince(lastComplianceRewardTime) >= 300 {
                    hapticManager.complianceReward()
                    lastComplianceRewardTime = Date()
                }
            }
        } else {
            complianceStreakStart = nil
        }
    }

    // MARK: - Location
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, isWorkoutActive else { return }

        if let last = lastLocation {
            let delta = location.distance(from: last)
            totalDistance += delta
            if isInZone {
                distanceInZone += delta
            }
        }

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

    // MARK: - Voice Diagnostics
    private func logAvailableVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }

        print("──── Available English voices (\(voices.count)) ────")
        for v in voices {
            let qualityLabel: String
            switch v.quality {
            case .premium:  qualityLabel = "premium"
            case .enhanced: qualityLabel = "enhanced"
            default:        qualityLabel = "default"
            }
            let gender: String
            switch v.gender {
            case .male:        gender = "male"
            case .female:      gender = "female"
            case .unspecified:  gender = "unspecified"
            @unknown default:  gender = "unknown"
            }
            print("  \(qualityLabel.padding(toLength: 9, withPad: " ", startingAt: 0)) | \(gender.padding(toLength: 12, withPad: " ", startingAt: 0)) | \(v.language.padding(toLength: 8, withPad: " ", startingAt: 0)) | \(v.name.padding(toLength: 20, withPad: " ", startingAt: 0)) | \(v.identifier)")
        }
        print("──── Selected voice: \(preferredVoice?.identifier ?? "nil") ────")
    }

    // MARK: - Speech
    private func speak(_ text: String) {
        guard !isPaused else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = preferredVoice
        synthesizer.speak(utterance)
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activity: activities disabled in Settings")
            return
        }
        let attributes = WorkoutActivityAttributes(
            targetLow: hrGuardrail.low,
            targetHigh: hrGuardrail.high,
            targetCadence: cadenceTarget.target
        )
        let initialState = WorkoutActivityAttributes.ContentState(
            heartRate: 0,
            zoneStatus: "ON TRACK",
            elapsedTime: 0,
            cadence: 0,
            isPaused: false
        )
        do {
            liveActivity = try Activity<WorkoutActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
            print("Live Activity started: \(liveActivity?.id ?? "unknown")")
        } catch {
            print("Live Activity failed to start: \(error.localizedDescription)")
        }
    }

    private func updateLiveActivity() {
        guard let activity = liveActivity else { return }
        let state = WorkoutActivityAttributes.ContentState(
            heartRate: Int(heartRate),
            zoneStatus: cueStatusString,
            elapsedTime: elapsedTime,
            cadence: Int(currentCadence),
            isPaused: isPaused
        )
        Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private var cueStatusString: String {
        switch activeCue {
        case .holdCadence:      return "ON TRACK"
        case .increaseCadence:  return "QUICK FEET"
        case .lightenStride:    return "LIGHTEN UP"
        case .reduceEffort:     return "EASE EFFORT"
        }
    }

    private func endLiveActivity() {
        guard let activity = liveActivity else { return }
        let finalState = WorkoutActivityAttributes.ContentState(
            heartRate: Int(heartRate),
            zoneStatus: cueStatusString,
            elapsedTime: elapsedTime,
            cadence: Int(currentCadence),
            isPaused: false
        )
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            liveActivity = nil
        }
    }

    // MARK: - BLE Heart Rate Monitor

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            let connected = central.retrieveConnectedPeripherals(withServices: [heartRateServiceUUID])
            if let peripheral = connected.first {
                connectToPeripheral(peripheral)
            } else {
                hrMonitorState = .searching
                central.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
            }
        default:
            hrMonitorState = .disconnected
            connectedDeviceName = nil
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        central.stopScan()
        connectToPeripheral(peripheral)
    }

    private func connectToPeripheral(_ peripheral: CBPeripheral) {
        connectedPeripheral = peripheral
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedDeviceName = peripheral.name
        hrMonitorState = .connected

        // Discover HR service so we can read HR data directly from chest strap
        peripheral.discoverServices([heartRateServiceUUID])

        // Source detection + haptics + voice
        let wasNotChestStrap = hrSource != .chestStrap
        hrSource = .chestStrap
        if wasNotChestStrap {
            sensorJustConnected = true
            hapticManager.chestStrapConnected()
            // If workout hasn't started yet, the coaching timer isn't running,
            // so speak immediately.
            if !isWorkoutActive {
                speak("Chest strap connected.")
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDeviceName = nil
        connectedPeripheral = nil
        hrMonitorState = .searching

        // Source detection + haptics
        if hrSource == .chestStrap {
            hrSource = .appleWatch
            sensorJustDisconnected = true
            hapticManager.sensorDisconnected()
            if !isWorkoutActive {
                speak("Heart rate monitor disconnected. Using Apple Watch heart rate.")
            }
        }

        // Automatically try to reconnect
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectedDeviceName = nil
        connectedPeripheral = nil
        hrMonitorState = .searching
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
    }

    // MARK: - BLE Service / Characteristic Discovery

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services where service.uuid == heartRateServiceUUID {
            peripheral.discoverCharacteristics([heartRateMeasurementUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics where characteristic.uuid == heartRateMeasurementUUID {
            // Subscribe to HR notifications from the chest strap
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    // MARK: - BLE Heart Rate Data
    // Parses the Bluetooth Heart Rate Measurement characteristic (0x2A37).
    // Byte 0 = flags, Byte 1 (or 1–2) = HR value.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == heartRateMeasurementUUID,
              let data = characteristic.value, data.count >= 2 else { return }

        let flags = data[0]
        let is16Bit = (flags & 0x01) != 0

        let hr: Double
        if is16Bit && data.count >= 3 {
            hr = Double(UInt16(data[1]) | (UInt16(data[2]) << 8))
        } else {
            hr = Double(data[1])
        }

        DispatchQueue.main.async {
            self.heartRate = hr
            self.hrSource = .chestStrap
            self.lastBLEHeartRateTime = Date()
            self.coachingEngine.addHeartRate(hr)
            self.updateZoneStatus()
        }
    }
}
