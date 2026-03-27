//
//  CloudKitSharingService.swift
//  FluffyList
//
//  Manages CloudKit sharing via NSPersistentCloudKitContainer's built-in API.
//

import CloudKit
import CoreData
import os.log
@preconcurrency import Dispatch

/// Manages CloudKit sharing for the household recipe library.
///
/// SwiftData uses NSPersistentCloudKitContainer internally to sync @Model objects.
/// To share data correctly, we must go through that container's
/// `share(_:to:completion:)` method rather than the raw CloudKit API.
/// Going through the container keeps Core Data's internal share-tracking metadata
/// in sync with the CKShare record in CloudKit.
///
/// The container reference is captured from SyncMonitor, which observes
/// `NSPersistentCloudKitContainer.eventChangedNotification`. SwiftData posts that
/// notification with the container as the sender, giving us a reference to the
/// same container SwiftData uses internally — no second container needed.
///
/// Sharing creates a CKShare for the zone where all SwiftData models live, so
/// new recipes added after sharing are automatically included.
///
/// Flow:
/// 1. Head Cook taps "Share" → `prepareShare(using:)`
/// 2. Any existing CKShare is deleted from CloudKit; NSPersistentCloudKitContainer
///    creates a brand-new CKShare (clean participants list, no applicationVersion)
/// 3. UICloudSharingController presents the system sharing UI
/// 4. Head Cook sends the share URL to Shannon (e.g. via iMessage)
/// 5. Shannon taps the link → AppDelegate accepts it → SwiftData (.automatic) syncs
@MainActor
final class CloudKitSharingService {
    static let shared = CloudKitSharingService()

    /// The CloudKit container identifier (matches entitlements).
    nonisolated static let containerIdentifier = "iCloud.com.highball71.FamilyMealPlanner"

    private let ckContainer: CKContainer
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.fluffylist",
        category: "Sharing"
    )

    private init() {
        ckContainer = CKContainer(identifier: Self.containerIdentifier)
    }

    // MARK: - Account

    /// Returns true if the user is signed into iCloud.
    func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await ckContainer.accountStatus()
            return status == .available
        } catch {
            logger.warning("Could not check iCloud status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Sharing

    /// Force-creates a brand-new household share via NSPersistentCloudKitContainer.
    ///
    /// Always deletes any existing CKShare from CloudKit before creating a fresh one.
    /// This guarantees a clean share with no stale participants and no applicationVersion
    /// field that triggers the "needs newer version" error for TestFlight recipients.
    ///
    /// If the container already tracks a share, its zone ID is used to construct a
    /// fresh CKShare(recordZoneID:) which is passed to share(_:to:). Passing a new
    /// CKShare object forces the container to adopt it rather than reusing its cached
    /// reference to the old share — which would carry over stale participants.
    ///
    /// - Parameter persistentContainer: The NSPersistentCloudKitContainer that backs SwiftData.
    ///   Captured from `NSPersistentCloudKitContainer.eventChangedNotification` by SyncMonitor.
    /// - Returns: (CKShare, CKContainer) ready for UICloudSharingController.
    func prepareShare(
        using persistentContainer: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, CKContainer) {
        guard await isCloudKitAvailable() else {
            throw CloudKitSharingError.accountNotAvailable
        }

        // Fetch Recipe managed objects from Core Data's main context.
        // We only need objects from any entity — Core Data uses them to identify
        // which zone to create the share for. Since all SwiftData models live in
        // the same zone, any non-empty set of objects is sufficient.
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDRecipe")
        let recipes = try persistentContainer.viewContext.fetch(request)

        guard !recipes.isEmpty else {
            throw CloudKitSharingError.noRecipesToShare
        }

        // Step 1: Check the container's local metadata for an existing share.
        // fetchShares(in:nil) is a synchronous CoreData read — no network, no hang.
        logger.info("prepareShare: step 1 — fetchShares starting")
        let existingShares = (try? persistentContainer.fetchShares(in: nil)) ?? []

        logger.info("prepareShare: step 1 — fetchShares complete, found \(existingShares.count) share(s)")

        // Step 2: Clean up stale shares that may reference deleted CloudKit zones.
        // After a reinstall or model migration, old share zones may no longer exist on
        // the server. Core Data's internal sync pipeline gets stuck trying to export to
        // those dead zones, which blocks share(_:to:). The hardResetSharing method does
        // a thorough cleanup: enumerates all custom zones, deletes any CKShare records
        // directly from CloudKit, and falls back to container metadata if needed.
        if !existingShares.isEmpty {
            logger.info("prepareShare: step 2 — found \(existingShares.count) stale share(s), running hard reset")
            do {
                try await hardResetSharing(persistentContainer: persistentContainer)
                logger.info("prepareShare: step 2 — hard reset complete")
            } catch {
                // Non-fatal: the zones may already be gone. Log and continue.
                logger.info("prepareShare: step 2 — hard reset finished with error (may be OK): \(error.localizedDescription)")
            }
            // Give CloudKit's sync pipeline a moment to process the zone deletions
            // before we ask it to create a new share. Without this pause, share(_:to:)
            // can get queued behind stale export operations that are still draining.
            logger.info("prepareShare: step 2 — waiting for sync pipeline to settle")
            try await Task.sleep(for: .seconds(3))
        } else {
            logger.info("prepareShare: step 2 — skipped (no existing shares)")
        }
        // Step 3: Create the new share via NSPersistentCloudKitContainer.
        // Always pass nil — let the container create a brand-new zone and share.
        logger.info("prepareShare: step 3 — share(_:to:) starting (nil — fresh creation)")
        let (share, shareContainer) = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(CKShare, CKContainer), Error>) in
            var resumed = false

            let timeoutWork = DispatchWorkItem {
                guard !resumed else { return }
                resumed = true
                continuation.resume(throwing: CloudKitSharingError.timeout)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWork)

            persistentContainer.share([recipes[0]]
, to: nil) { [logger] _, share, container, error in
                DispatchQueue.main.async {
                    guard !resumed else { return }
                    resumed = true
                    timeoutWork.cancel()
                    if let error {
                        logger.error("prepareShare: step 3 — share(_:to:) failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else if let share, let container {
                        logger.info("prepareShare: step 3 — share(_:to:) complete, URL: \(share.url?.absoluteString ?? "none yet", privacy: .public)")
                        continuation.resume(returning: (share, container))
                    } else {
                        logger.error("prepareShare: step 3 — share(_:to:) returned nil share/container")
                        continuation.resume(throwing: CloudKitSharingError.shareFailed)
                    }
                }
            }
        }

        // The CloudKit framework automatically writes the app's CFBundleVersion into
        // the "applicationVersion" field of the CKShare when saving it. When a
        // recipient taps the share link, iOS reads this field and looks up that
        // build number in the App Store to verify compatibility. TestFlight builds
        // are not in the App Store, so the check fails with "You need a newer version
        // … couldn't be found in the App Store" even if the recipient has the correct
        // TestFlight build installed.
        //
        // Clearing the field removes the version gate entirely. The share still works;
        // iOS just skips the App Store version check.
        await clearApplicationVersion(from: share, using: shareContainer)

        return (share, shareContainer)
    }

    /// Returns the active CKShare managed by NSPersistentCloudKitContainer, or nil
    /// if no share has been created yet.
    ///
    /// Also clears `applicationVersion` if UICloudSharingController re-set it during
    /// a previous participant-management interaction.
    func existingShare(using persistentContainer: NSPersistentCloudKitContainer) async -> CKShare? {
        // fetchShares(in: nil) returns all CKShares Core Data is managing across
        // all persistent stores. For this app there should only ever be one.
        do {
            let shares = try persistentContainer.fetchShares(in: nil)
            guard let share = shares.first else { return nil }

            // UICloudSharingController can re-set applicationVersion when it saves
            // the share (e.g. after the user adds a participant). Clear it again
            // so the App Store version check doesn't re-appear on the next send.
            if share["applicationVersion"] as? String != nil {
                await clearApplicationVersion(from: share, using: ckContainer)
            }

            return share
        } catch {
            logger.warning("Could not fetch existing shares: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Hard Reset

    /// Nukes the existing CKShare from CloudKit, bypassing NSPersistentCloudKitContainer
    /// entirely. Safe to call even when the container's sync state is stuck or corrupted.
    ///
    /// Two-path strategy:
    ///   PRIMARY — enumerate all custom CloudKit zones and delete CKShare records
    ///   directly via CKDatabase. No container involvement at all.
    ///
    ///   FALLBACK — if the zone query finds nothing (e.g., CloudKit restricts querying
    ///   the "cloudkit.share" system record type in this environment), fall back to
    ///   `fetchShares(in:)`, which is a *synchronous local CoreData read* that cannot
    ///   hang even if sync is broken, then delete via raw CKDatabase.
    ///
    /// Enforces a 15-second timeout and respects Swift Task cancellation throughout.
    func hardResetSharing(persistentContainer: NSPersistentCloudKitContainer?) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                try await self.performHardReset(using: persistentContainer)
            }
            group.addTask {
                // Hard deadline — the operation cannot spin forever.
                try await Task.sleep(for: .seconds(15))
                throw CloudKitSharingError.timeout
            }
            // First result wins; cancel the other task immediately.
            do {
                try await group.next()!
            } catch {
                group.cancelAll()
                throw error
            }
            group.cancelAll()
        }
    }

    private func performHardReset(using persistentContainer: NSPersistentCloudKitContainer?) async throws {
        // PRIMARY: direct CloudKit zone query — no container needed.
        var nukedViaQuery = false
        do {
            let count = try await deleteSharesViaDirectQuery()
            nukedViaQuery = count > 0
            logger.info("Hard reset: deleted \(count) share(s) directly from CloudKit")
        } catch {
            logger.warning(
                "Direct zone query failed, trying container fallback: \(error.localizedDescription, privacy: .public)"
            )
        }

        guard !nukedViaQuery else { return }

        // FALLBACK: fetchShares(in:) reads the local CoreData store — it's synchronous
        // and cannot hang. Use the result to drive a raw CKDatabase delete.
        guard let container = persistentContainer else {
            logger.info("Hard reset: no container available — CloudKit may already be clean")
            return
        }
        let shares = (try? container.fetchShares(in: nil)) ?? []
        guard let share = shares.first else {
            logger.info("Hard reset: no shares found — already clean")
            return
        }
        _ = try await ckContainer.privateCloudDatabase.modifyRecords(
            saving: [], deleting: [share.recordID]
        )
        logger.info("Hard reset: deleted share via container-ID fallback")
    }

    /// Fetches all custom zones in the private database and deletes any CKShare records
    /// found there — no NSPersistentCloudKitContainer involvement.
    private func deleteSharesViaDirectQuery() async throws -> Int {
        let allZones = try await ckContainer.privateCloudDatabase.allRecordZones()
        // NSPersistentCloudKitContainer stores data in custom zones, never the default zone.
        let customZones = allZones.filter { $0.zoneID != CKRecordZone.default().zoneID }

        var toDelete: [CKRecord.ID] = []
        for zone in customZones {
            // CKRecord.SystemType.share == "cloudkit.share"
            // CloudKit may restrict querying system record types in some configurations;
            // the caller catches any error and falls through to the container fallback.
            let query = CKQuery(
                recordType: CKRecord.SystemType.share,
                predicate: NSPredicate(value: true)
            )
            let (matchResults, _) = try await ckContainer.privateCloudDatabase.records(
                matching: query, inZoneWith: zone.zoneID
            )
            toDelete += matchResults.compactMap { _, result in try? result.get().recordID }
        }

        guard !toDelete.isEmpty else { return 0 }
        _ = try await ckContainer.privateCloudDatabase.modifyRecords(saving: [], deleting: toDelete)
        return toDelete.count
    }

    // MARK: - Direct CloudKit query (no container)

    /// Fetches the existing CKShare directly from CloudKit without involving
    /// NSPersistentCloudKitContainer. Used as a fallback when persistentContainer
    /// hasn't been captured yet from sync event notifications (e.g. right after
    /// a hard reset deleted the zone and sync hasn't restarted).
    ///
    /// Uses the same zone-enumeration approach as deleteSharesViaDirectQuery.
    /// Returns the first CKShare found, or nil if no custom zones / no shares exist.
    func fetchExistingShareDirect() async throws -> CKShare? {
        let allZones = try await ckContainer.privateCloudDatabase.allRecordZones()
        let customZones = allZones.filter { $0.zoneID != CKRecordZone.default().zoneID }

        for zone in customZones {
            let query = CKQuery(
                recordType: CKRecord.SystemType.share,
                predicate: NSPredicate(value: true)
            )
            let (matchResults, _) = try await ckContainer.privateCloudDatabase.records(
                matching: query, inZoneWith: zone.zoneID
            )
            let shares = matchResults.compactMap { _, result -> CKShare? in
                try? result.get() as? CKShare
            }
            if let share = shares.first {
                // Clear applicationVersion so the App Store version check doesn't appear.
                if share["applicationVersion"] as? String != nil {
                    await clearApplicationVersion(from: share, using: ckContainer)
                }
                return share
            }
        }
        return nil
    }

    // MARK: - Private helpers

    /// Clears the `applicationVersion` field from a CKShare and re-saves it directly
    /// to CloudKit. This is safe to call outside NSPersistentCloudKitContainer's sync
    /// path because `applicationVersion` is pure iOS-side metadata — the container
    /// never reads or manages it, so the direct write doesn't interfere with sync.
    ///
    /// Called by CloudSharingDelegate after UICloudSharingController saves the share,
    /// in addition to the existing call sites in prepareShare and existingShare.
    func clearApplicationVersion(from share: CKShare, using container: CKContainer) async {
        share["applicationVersion"] = nil as CKRecordValue?
        do {
            _ = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
            logger.info("Cleared applicationVersion from share.")
        } catch {
            // Non-fatal: log and continue. The share still works; recipients on
            // TestFlight may see the version error one more time until the next
            // successful clear.
            logger.warning("Could not clear applicationVersion: \(error.localizedDescription)")
        }
    }

    // MARK: - User Identity

    /// Fetches the current user's iCloud display name using the modern
    /// `CKFetchShareParticipantsOperation` API (replaces the deprecated
    /// `CKContainer.discoverUserIdentity` removed in iOS 17).
    ///
    /// Returns nil when the user hasn't enabled iCloud discoverability,
    /// is not signed in, or a network error occurs.
    func fetchCurrentUserDisplayName() async -> String? {
        do {
            let recordID = try await ckContainer.userRecordID()
            let lookupInfo = CKUserIdentity.LookupInfo(userRecordID: recordID)

            // CKFetchShareParticipantsOperation has no native async overload —
            // wrap with a checked continuation.
            let name: String? = try await withCheckedThrowingContinuation { continuation in
                var fetchedName: String? = nil

                let operation = CKFetchShareParticipantsOperation(
                    userIdentityLookupInfos: [lookupInfo]
                )
                operation.qualityOfService = .userInitiated

                operation.perShareParticipantResultBlock = { _, result in
                    if case .success(let participant) = result,
                       let components = participant.userIdentity.nameComponents {
                        let formatter = PersonNameComponentsFormatter()
                        formatter.style = .default
                        let n = formatter.string(from: components)
                        if !n.isEmpty { fetchedName = n }
                    }
                }

                operation.fetchShareParticipantsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: fetchedName)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                self.ckContainer.add(operation)
            }
            return name
        } catch {
            logger.info("Could not fetch iCloud display name: \(error.localizedDescription)")
            return nil
        }
    }
}

/// Errors specific to CloudKit sharing operations.
enum CloudKitSharingError: LocalizedError {
    case accountNotAvailable
    case noRecipesToShare
    case shareFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            "iCloud account is not available — sign in to share recipes"
        case .noRecipesToShare:
            "Add at least one recipe before sharing your library"
        case .shareFailed:
            "CloudKit did not return a valid share — please try again"
        case .timeout:
            "Sharing timed out — check your internet connection and try again"
        }
    }
}
