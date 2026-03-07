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

    enum HRMonitorState {
        case disconnected
        case searching
        case connected
    }
    
    // MARK: - Settings
    var lowHR: Int = 120
    var highHR: Int = 150
    
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

    // BLE heart rate monitor tracking
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private let heartRateServiceUUID = CBUUID(string: "180D")
    
    enum ZoneStatus: String {
        case belowZone = "SPEED UP"
        case inZone = "IN THE ZONE"
        case aboveZone = "SLOW DOWN"
    }
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5
        locationManager.activityType = .fitness
        centralManager = CBCentralManager(delegate: self, queue: nil)
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
        
        startHeartRateQuery()
        locationManager.startUpdatingLocation()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.elapsedTime = Date().timeIntervalSince(self.startDate ?? Date())
            if self.isInZone {
                self.timeInZone += 1
            }
        }
        
        speak("Workout started. Target zone: \(lowHR) to \(highHR) beats per minute.")
    }
    
    func stopWorkout() {
        isWorkoutActive = false
        heartRateQuery = nil
        timer?.invalidate()
        timer = nil
        locationManager.stopUpdatingLocation()
        
        let minutes = Int(timeInZone) / 60
        let seconds = Int(timeInZone) % 60
        let distanceMiles = distanceInZone * 0.000621371
        speak("Workout complete. You spent \(minutes) minutes and \(seconds) seconds in your zone, covering \(String(format: "%.1f", distanceMiles)) miles.")
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
        
        DispatchQueue.main.async {
            self.heartRate = hr
            self.updateZoneStatus()
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

    // MARK: - BLE Heart Rate Monitor
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            // Check for already-connected HR peripherals first
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
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectedDeviceName = nil
        connectedPeripheral = nil
        hrMonitorState = .searching
        // Automatically try to reconnect
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectedDeviceName = nil
        connectedPeripheral = nil
        hrMonitorState = .searching
        centralManager.scanForPeripherals(withServices: [heartRateServiceUUID], options: nil)
    }
}
