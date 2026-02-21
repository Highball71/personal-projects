import CoreLocation
import Observation

/// Monitors user location for arrival detection.
/// When the user starts a trip and specifies a destination with coordinates,
/// this service watches for arrival and fires a callback so the app can
/// prompt for the ending odometer reading.
@Observable
class LocationService: NSObject {
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var isMonitoring = false

    /// Called when the user arrives near a monitored destination.
    var onArrival: (() -> Void)?

    private let locationManager = CLLocationManager()
    private var destinationRegion: CLCircularRegion?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Permissions

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    // MARK: - Arrival Monitoring

    /// Start monitoring for arrival at a destination with known coordinates.
    /// Uses a 200-meter geofence radius — close enough for "you've arrived" detection.
    func monitorArrival(latitude: Double, longitude: Double, identifier: String = "destination") {
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let region = CLCircularRegion(center: center, radius: 200, identifier: identifier)
        region.notifyOnEntry = true
        region.notifyOnExit = false

        destinationRegion = region
        locationManager.startMonitoring(for: region)
        isMonitoring = true
    }

    /// Stop monitoring for arrival.
    func stopMonitoring() {
        if let region = destinationRegion {
            locationManager.stopMonitoring(for: region)
        }
        destinationRegion = nil
        isMonitoring = false
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        Task { @MainActor in
            self.onArrival?()
            self.stopMonitoring()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Region monitoring failed: \(error)")
        Task { @MainActor in
            self.stopMonitoring()
        }
    }
}
