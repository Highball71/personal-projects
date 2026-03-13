//
//  SyncMonitor.swift
//  FluffyList
//
//  Tracks CloudKit sync state and network connectivity for status indicators.
//

import CoreData
import Network
import Observation

/// Tracks CloudKit sync state and network reachability.
/// Inject into the environment at app level; observe in views.
@Observable
final class SyncMonitor {

    enum SyncState: Equatable {
        case synced
        case syncing
        case error(String)
    }

    // MARK: - Published state

    /// Current CloudKit sync state. Updated by NSPersistentCloudKitContainer event notifications.
    private(set) var syncState: SyncState = .synced

    /// True when the device has no network path (airplane mode, no Wi-Fi/cellular).
    private(set) var isOffline: Bool = false

    // MARK: - Private

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.highball71.fluffylist.network", qos: .utility)
    private var cloudKitObserver: NSObjectProtocol?

    init() {
        startNetworkMonitoring()
        startCloudKitEventMonitoring()
    }

    deinit {
        pathMonitor.cancel()
        if let cloudKitObserver {
            NotificationCenter.default.removeObserver(cloudKitObserver)
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOffline = path.status != .satisfied
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    // MARK: - CloudKit Event Monitoring

    private func startCloudKitEventMonitoring() {
        cloudKitObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }
            self?.handleCloudKitEvent(event)
        }
    }

    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        if event.endDate == nil {
            // No end date → event is still in progress
            syncState = .syncing
        } else if event.succeeded {
            syncState = .synced
        } else {
            let message = event.error?.localizedDescription ?? "Sync failed"
            syncState = .error(message)
        }
    }
}
