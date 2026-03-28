//
//  SyncMonitor.swift
//  Family Meal Planner
//
//  Tracks CloudKit sync state and network connectivity for status indicators.
//
//  Supports explicit container binding via attach(to:) / detach() so the
//  monitor can observe a fresh container after a local store reset.
//

import CloudKit
import CoreData
import Network
import Observation
import os

/// Tracks CloudKit sync state and network reachability.
/// Inject into the environment at app level; observe in views.
@Observable
final class SyncMonitor: @unchecked Sendable {

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

    /// The NSPersistentCloudKitContainer currently being observed.
    /// Set via attach(to:) or auto-captured from the first CloudKit event notification.
    /// CloudKitSharingService uses this to call share(_:to:completion:).
    private(set) var persistentContainer: NSPersistentCloudKitContainer?

    /// True once at least one export event has completed successfully.
    /// The share flow should wait for this before calling share(_:to:)
    /// because objects can't be shared until they've been exported to CloudKit.
    private(set) var hasCompletedExport: Bool = false

    /// The last sync error message, persisted so the UI can display it
    /// even after the state flips back to .syncing.
    private(set) var lastErrorMessage: String?

    // MARK: - Private

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.highball71.fluffylist.network", qos: .utility)
    private var cloudKitObserver: NSObjectProtocol?
    private let logger = Logger.cloudkit

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

    // MARK: - Container Lifecycle

    /// Explicitly bind to a new container. Removes the old observer and
    /// registers a fresh one scoped to the new container.
    ///
    /// Call this after `PersistenceController.resetLocalStoresAndRebuildContainer()`
    /// so the monitor observes the replacement container, not the dead one.
    func attach(to container: NSPersistentCloudKitContainer) {
        detach()
        persistentContainer = container
        startCloudKitEventMonitoring()

        #if DEBUG
        // Push the complete CloudKit schema from the new container.
        let logger = Logger.cloudkit
        Task.detached(priority: .background) {
            do {
                try container.initializeCloudKitSchema(options: [])
                logger.info("initializeCloudKitSchema: Development schema updated (after attach)")
            } catch {
                logger.warning(
                    "initializeCloudKitSchema failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
        #endif
    }

    /// Removes the CloudKit event observer and clears the container reference.
    /// Call before attaching to a new container, or during cleanup.
    func detach() {
        if let cloudKitObserver {
            NotificationCenter.default.removeObserver(cloudKitObserver)
            self.cloudKitObserver = nil
        }
        persistentContainer = nil
    }

    /// Resets the sync state to defaults. Useful after a local store reset
    /// when the previous state is no longer meaningful.
    func resetState() {
        syncState = .synced
        hasCompletedExport = false
        lastErrorMessage = nil
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { [weak self] in
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
            // If we don't have a container yet (first launch, before attach),
            // capture it from the notification sender.
            if let container = notification.object as? NSPersistentCloudKitContainer,
               self?.persistentContainer == nil {
                self?.persistentContainer = container

                // One-time launch cleanup: clear any stale applicationVersion from the
                // live CKShare in CloudKit.
                Task {
                    _ = await CloudKitSharingService.shared.existingShare(using: container)
                }
            }

            guard let event = notification.userInfo?[
                NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            ] as? NSPersistentCloudKitContainer.Event else { return }
            self?.handleCloudKitEvent(event)
        }
    }

    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let eventType: String
        switch event.type {
        case .setup:  eventType = "setup"
        case .import: eventType = "import"
        case .export: eventType = "export"
        @unknown default: eventType = "unknown"
        }

        if event.endDate == nil {
            // No end date -> event is still in progress
            logger.info("CloudKit event started: \(eventType)")
            syncState = .syncing
        } else if event.succeeded {
            logger.info("CloudKit event succeeded: \(eventType)")
            syncState = .synced
            lastErrorMessage = nil

            // Track that at least one export has succeeded — objects are now
            // in CloudKit and can be shared.
            if event.type == .export {
                hasCompletedExport = true
            }
        } else {
            let message = event.error?.localizedDescription ?? "Sync failed"
            logger.error("CloudKit event FAILED: \(eventType) — \(message, privacy: .public)")

            // Log the underlying error code for debugging
            if let ckError = event.error as? CKError {
                logger.error("  CKError code: \(ckError.code.rawValue) (\(String(describing: ckError.code)))")
                if let retryAfter = ckError.retryAfterSeconds {
                    logger.error("  retryAfter: \(retryAfter)s")
                }
                if let underlying = ckError.userInfo[NSUnderlyingErrorKey] as? Error {
                    logger.error("  underlying: \(underlying.localizedDescription, privacy: .public)")
                }
            }

            syncState = .error(message)
            lastErrorMessage = message
        }
    }
}
