//
//  SyncMonitor.swift
//  FluffyList
//
//  Tracks CloudKit sync state and network connectivity for status indicators.
//

import CoreData
import Network
import Observation
import os

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

    /// The NSPersistentCloudKitContainer that backs SwiftData, captured from the first
    /// CloudKit event notification (which includes the container as the notification sender).
    /// Available once the first sync event fires — typically within seconds of launch.
    /// CloudKitSharingService uses this to call share(_:to:completion:).
    private(set) var persistentContainer: NSPersistentCloudKitContainer?

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
            // The notification sender is the NSPersistentCloudKitContainer that
            // SwiftData created internally. Capture it once so CloudKitSharingService
            // can use it for share(_:to:completion:) without needing a second container.
            if let container = notification.object as? NSPersistentCloudKitContainer,
               self?.persistentContainer == nil {
                self?.persistentContainer = container

                // One-time launch cleanup: clear any stale applicationVersion from the
                // live CKShare in CloudKit. This patches shares created before the fix
                // was introduced. existingShare(using:) already does the conditional
                // clear-and-save, so we just fire it and discard the return value.
                Task {
                    _ = await CloudKitSharingService.shared.existingShare(using: container)
                }

                #if DEBUG
                // Push the complete CloudKit schema — including all internal
                // NSPersistentCloudKitContainer fields — to the Development environment.
                //
                // Why this is needed: fields like CD_moveRecipe are framework-internal
                // (used only by share(_:to:completion:)) and are never created by normal
                // SwiftData sync. They are absent from both Development and Production,
                // so sharing fails with "Cannot create or modify field" even after a
                // schema deploy. initializeCloudKitSchema creates every internal field
                // at once. Run a debug build once after this change, then deploy from
                // the CloudKit Console — sharing will work after that.
                //
                // Safe to leave permanently: only runs in debug builds (Development
                // CloudKit environment), is a no-op after all fields already exist,
                // and works on a temporary in-memory copy so it doesn't touch live data.
                Task.detached(priority: .background) {
                    do {
                        try container.initializeCloudKitSchema(options: [])
                        Logger.cloudkit.info("initializeCloudKitSchema: Development schema updated")
                    } catch {
                        Logger.cloudkit.warning(
                            "initializeCloudKitSchema failed: \(error.localizedDescription, privacy: .public)"
                        )
                    }
                }
                #endif
            }

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
