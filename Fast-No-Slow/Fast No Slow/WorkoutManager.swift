import Foundation
import HealthKit
import CoreLocation
import CoreBluetooth
import AVFoundation
import Combine

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

    // New: HR source, cadence, coaching, compliance
    @Published var hrSource: HRSource = .unknown
    @Published var currentCadence: Double = 0
    @Published var coachingState: CoachingState = .stable
    @Published var timeOnCadence: TimeInterval = 0
    @Published var showSummary: Bool = false

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
    var lowHR: Int = 120
    var highHR: Int = 150
    var targetCadence: Int = 170
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

    // Cancellables for cadence observation
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        centralManager = CBCentralManager(delegate: self, queue: nil)

        // Forward cadence from CadenceManager
        cadenceManager.$currentCadence
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentCadence)
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
        timeOnCadence = 0
        previousElevation = nil
        lastLocation = nil
        lastInZoneLocation = nil
        showSummary = false
        complianceStreakStart = nil
        lastComplianceRewardTime = .distantPast

        // Configure coaching engine
        coachingEngine.lowHR = lowHR
        coachingEngine.highHR = highHR
        coachingEngine.targetCadence = targetCadence
        coachingEngine.reset()

        startHeartRateQuery()
        locationManager.startUpdatingLocation()
        cadenceManager.startTracking()

        // Start metronome
        metronomeEngine.start(mode: metronomeMode, targetBPM: Double(targetCadence))

        // 1-second coaching/tracking timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.startDate ?? Date())
            if self.isInZone {
                self.timeInZone += 1
            }
            // Cadence compliance: on target if within ±10 SPM
            if self.currentCadence > 0 &&
                abs(self.currentCadence - Double(self.targetCadence)) <= 10 {
                self.timeOnCadence += 1
            }

            // Update metronome with current cadence
            self.metronomeEngine.updateCadence(self.currentCadence)

            // Run coaching evaluation
            self.runCoaching()

            // Compliance streak check (HR in zone AND cadence on target)
            self.checkComplianceStreak()
        }

        speak("Workout started. Target zone: \(lowHR) to \(highHR) beats per minute.")
    }

    func stopWorkout() {
        isWorkoutActive = false
        heartRateQuery = nil
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        cadenceManager.stopTracking()
        metronomeEngine.stop()

        let minutes = Int(timeInZone) / 60
        let seconds = Int(timeInZone) % 60
        let distanceMiles = distanceInZone * 0.000621371
        speak("Workout complete. You spent \(minutes) minutes and \(seconds) seconds in your zone, covering \(String(format: "%.1f", distanceMiles)) miles.")

        showSummary = true
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
    }

    // MARK: - Coaching
    private func runCoaching() {
        let cue = coachingEngine.evaluate(
            cadence: currentCadence,
            hrSource: hrSource,
            sensorJustDisconnected: sensorJustDisconnected,
            sensorJustConnected: sensorJustConnected
        )

        // Clear one-shot flags
        sensorJustConnected = false
        sensorJustDisconnected = false

        coachingState = coachingEngine.activeState

        if let cue = cue {
            speak(cue)
        }
    }

    // MARK: - Compliance Streak (haptic reward)
    private func checkComplianceStreak() {
        let hrOK = isInZone
        let cadenceOK = currentCadence > 0 &&
            abs(currentCadence - Double(targetCadence)) <= 10

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

    // MARK: - Speech
    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
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
