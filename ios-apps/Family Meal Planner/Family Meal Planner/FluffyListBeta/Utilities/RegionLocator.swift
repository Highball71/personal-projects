//
//  RegionLocator.swift
//  FluffyList
//
//  One-shot "Use my location" → USRegion for the seasonal region
//  prompt: request when-in-use authorization (the system asks at most
//  once), take a single reduced-accuracy fix, reverse-geocode it to a
//  US state, and map the state through StateRegionMap. Every failure
//  mode — denied, restricted, no fix, geocoder error, outside the US,
//  an unmapped state (Hawaii) — returns nil, and the prompt falls
//  back to the manual picker. Nothing is stored: the fix and the
//  address die with this call; only the chosen region persists
//  (the existing "seasonalRegion" setting).
//
//  Geocoding uses MapKit's MKReverseGeocodingRequest (CLGeocoder is
//  deprecated at this deployment target). The new address API has no
//  structured state field, so the state is the trailing component of
//  cityWithContext ("Cupertino, CA" → "CA") — StateRegionMap accepts
//  codes and full names either way.
//
//  MainActor class with nonisolated CLLocationManagerDelegate
//  callbacks hopping back via Task { @MainActor } — the same posture
//  as the rest of the app under default MainActor isolation.
//

import CoreLocation
import MapKit
import os

@MainActor
final class RegionLocator: NSObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()
    /// Waiting for the authorization dialog to resolve.
    private var authWaiter: CheckedContinuation<Void, Never>?
    /// Waiting for the single requestLocation() fix (or its failure).
    private var locationWaiter: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        // A state is a big target — the reduced-accuracy fix is
        // faster, kinder to the battery, and all the geocoder needs.
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    /// The whole flow. nil means "couldn't determine a region" — the
    /// caller shows the manual picker, never an error alert.
    func locateRegion() async -> USRegion? {
        var status = manager.authorizationStatus
        if status == .notDetermined {
            await withCheckedContinuation { continuation in
                authWaiter = continuation
                manager.requestWhenInUseAuthorization()
            }
            status = manager.authorizationStatus
        }
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            Logger.supabase.info("RegionLocator: authorization not granted (\(status.rawValue))")
            return nil
        }

        let fix = await withCheckedContinuation { continuation in
            locationWaiter = continuation
            manager.requestLocation()
        }
        guard let fix else { return nil }
        guard let state = await usState(for: fix) else {
            Logger.supabase.info("RegionLocator: no US state from geocoder")
            return nil
        }
        return StateRegionMap.region(forState: state)
    }

    /// Reverse-geocode one fix to a US state, or nil (error, outside
    /// the US, or an address without a city-with-context line).
    private func usState(for location: CLLocation) async -> String? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first,
              let address = item.addressRepresentations,
              address.region?.identifier == "US",
              let cityWithContext = address.cityWithContext
        else { return nil }
        return cityWithContext
            .components(separatedBy: ",").last?
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Also fires with the initial status when the delegate is set;
        // with no waiter that's a no-op.
        Task { @MainActor in
            authWaiter?.resume()
            authWaiter = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        let latest = locations.last
        Task { @MainActor in
            locationWaiter?.resume(returning: latest)
            locationWaiter = nil
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        let message = error.localizedDescription
        Task { @MainActor in
            Logger.supabase.info("RegionLocator: location failed \u{2014} \(message)")
            locationWaiter?.resume(returning: nil)
            locationWaiter = nil
        }
    }
}
