//
//  CloudKitSharingService.swift
//  Family Meal Planner
//
//  THE single source of truth for CloudKit sharing.
//  Manages household sharing via NSPersistentCloudKitContainer's built-in API.
//
//  This is the only sharing service — HouseholdShareService.swift is deprecated
//  and should not be called. ShareCoordinator.swift remains as a UI delegate helper.
//

import CloudKit
import CoreData
import os.log
/// Manages CloudKit sharing for the household recipe library.
///
/// Core Data uses NSPersistentCloudKitContainer internally to sync objects.
/// To share data correctly, we go through that container's
/// `share(_:to:completion:)` method rather than the raw CloudKit API.
/// Going through the container keeps Core Data's internal share-tracking metadata
/// in sync with the CKShare record in CloudKit.
///
/// The container reference is captured from SyncMonitor, which observes
/// `NSPersistentCloudKitContainer.eventChangedNotification`.
///
/// KEY CHANGE: We now share the CDHousehold root object, not an arbitrary recipe.
/// This is the correct model: one household owns all recipes, meal plans, groceries,
/// and members. Sharing the household shares everything underneath it.
///
/// Flow:
/// 1. Head Cook taps "Share" -> `startShareFlow(from:)`
/// 2. Any existing CKShare is deleted; container creates a brand-new CKShare
/// 3. UICloudSharingController presents the system sharing UI
/// 4. Head Cook sends the share URL (e.g. via iMessage)
/// 5. Recipient taps the link -> AppDelegate accepts it -> CloudKit syncs
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

    // MARK: - Single Entry Point

    /// The primary sharing entry point. Creates a fresh share for the household.
    ///
    /// This method:
    /// 1. Refreshes the context to discard stale in-memory objects
    /// 2. Finds or creates the household root object (typed CDHousehold fetch)
    /// 3. Verifies the household lives in the private store (required for sharing)
    /// 4. Cleans up any stale CKShare records
    /// 5. Calls share(_:to:nil) on the HOUSEHOLD (not a recipe)
    /// 6. Clears applicationVersion for TestFlight compatibility
    ///
    /// - Parameters:
    ///   - persistentContainer: The NSPersistentCloudKitContainer — must be
    ///     the CURRENT container (not one from before a local reset).
    ///   - syncMonitor: Optional SyncMonitor to check if at least one export
    ///     has completed. If provided and no export has completed yet, this
    ///     method waits up to 15 seconds for the initial export cycle.
    /// - Returns: (CKShare, CKContainer) ready for UICloudSharingController.
    func startShareFlow(
        from persistentContainer: NSPersistentCloudKitContainer,
        syncMonitor: SyncMonitor? = nil
    ) async throws -> (CKShare, CKContainer) {
        guard await isCloudKitAvailable() else {
            throw CloudKitSharingError.accountNotAvailable
        }

        let context = persistentContainer.viewContext

        // Step 0a: Wait for at least one successful export cycle.
        // Objects must be exported to CloudKit before they can be shared.
        // If we try to share before the initial export, share(_:to:) hangs
        // because the container's internal exporter is still processing.
        if let syncMonitor, !syncMonitor.hasCompletedExport {
            logger.info("startShareFlow: step 0a — waiting for initial export to complete")
            for i in 0..<30 {
                guard !Task.isCancelled else { throw CancellationError() }
                try await Task.sleep(for: .milliseconds(500))
                if syncMonitor.hasCompletedExport {
                    logger.info("startShareFlow: step 0a — export completed after \(i * 500)ms")
                    break
                }
                if case .error(let msg) = syncMonitor.syncState {
                    logger.warning("startShareFlow: step 0a — sync error while waiting: \(msg, privacy: .public)")
                    // Don't give up on transient errors — keep waiting
                }
            }
            if !syncMonitor.hasCompletedExport {
                logger.error("startShareFlow: step 0a — no successful export after 15s")
                throw CloudKitSharingError.exportNotReady
            }
        }

        // Step 0b: Refresh the context so we don't pick up stale objects from
        // before a container rebuild. This is cheap and prevents the most common
        // cause of share(_:to:) hanging — passing an object whose underlying
        // row cache doesn't match the current store coordinator.
        logger.info("startShareFlow: step 0b — refreshing viewContext to discard stale objects")
        context.refreshAllObjects()

        // Step 1: Fetch the household root object using a TYPED fetch request.
        // This ensures we get a real CDHousehold, not a generic NSManagedObject.
        logger.info("startShareFlow: step 1 — fetching CDHousehold from current container")
        let householdRequest = CDHousehold.fetchRequest()
        let households = try context.fetch(householdRequest)

        guard let household = households.first else {
            // Auto-create if missing (e.g. fresh install or post-reset).
            logger.warning("startShareFlow: step 1 — no household found, creating one")
            let newHousehold = CDHousehold(context: context)
            newHousehold.id = UUID()
            newHousehold.name = "My Household"
            try context.save()
            // Re-fetch to ensure the object is fully materialized with a permanent ID.
            let refetch = try context.fetch(householdRequest)
            guard let created = refetch.first else {
                throw CloudKitSharingError.noHouseholdToShare
            }
            return try await continueShareFlow(
                household: created,
                persistentContainer: persistentContainer
            )
        }

        logger.info("startShareFlow: step 1 — found household '\(household.name)'")

        // Step 1b: Verify the household is in the private store.
        // Objects in the shared store cannot be the root of a NEW share.
        let objectID = household.objectID
        if let assignedStore = objectID.persistentStore,
           assignedStore.configurationName == "Shared" {
            logger.error("startShareFlow: step 1b — household is in the Shared store, cannot share")
            throw CloudKitSharingError.householdInWrongStore
        }

        return try await continueShareFlow(
            household: household,
            persistentContainer: persistentContainer
        )
    }

    /// Continues the share flow after a valid household has been obtained.
    private func continueShareFlow(
        household: CDHousehold,
        persistentContainer: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, CKContainer) {

        // Step 2: Check the container's local metadata for an existing share.
        logger.info("startShareFlow: step 2 — fetchShares starting")
        let existingShares = (try? persistentContainer.fetchShares(in: nil)) ?? []
        logger.info("startShareFlow: step 2 — fetchShares complete, found \(existingShares.count) share(s)")

        // Step 3: Clean up stale shares.
        if !existingShares.isEmpty {
            logger.info("startShareFlow: step 3 — found \(existingShares.count) stale share(s), running hard reset")
            do {
                try await hardResetSharing(persistentContainer: persistentContainer)
                logger.info("startShareFlow: step 3 — hard reset complete")
            } catch {
                logger.info("startShareFlow: step 3 — hard reset finished with error (may be OK): \(error.localizedDescription)")
            }
            logger.info("startShareFlow: step 3 — waiting for sync pipeline to settle")
            try await Task.sleep(for: .seconds(3))
        } else {
            logger.info("startShareFlow: step 3 — skipped (no existing shares)")
        }

        // Step 4: Re-fetch the household FRESH after any cleanup.
        // This guarantees the object is from the current context and not invalidated
        // by the hard reset or pipeline settlement.
        logger.info("startShareFlow: step 4 — re-fetching household after cleanup")
        persistentContainer.viewContext.refreshAllObjects()
        let refetchRequest = CDHousehold.fetchRequest()
        let freshHouseholds = try persistentContainer.viewContext.fetch(refetchRequest)
        guard let freshHousehold = freshHouseholds.first else {
            throw CloudKitSharingError.noHouseholdToShare
        }

        // Step 5a: Ensure the household has a PERMANENT objectID.
        // Core Data + CloudKit requires permanent IDs before sharing.
        // Without this, share(_:to:nil) can hang indefinitely because
        // the mirroring delegate can't map the object to a CKRecord.
        let objectID = freshHousehold.objectID
        if objectID.isTemporaryID {
            logger.info("startShareFlow: step 5a — obtaining permanent ID (was temporary)")
            try persistentContainer.viewContext.obtainPermanentIDs(for: [freshHousehold])
            logger.info("startShareFlow: step 5a — permanent ID obtained: \(freshHousehold.objectID)")
        } else {
            logger.info("startShareFlow: step 5a — objectID is already permanent")
        }

        // Step 5b: Create the new share via NSPersistentCloudKitContainer.
        // CRITICAL: Pass the HOUSEHOLD object, not a recipe.
        // This shares the entire household graph (recipes, plans, groceries, members).
        //
        // IMPORTANT: We use the ASYNC version of share(_:to:) (iOS 16+).
        // The callback-based version deadlocks when called from @MainActor
        // because it internally calls performBlockAndWait on the viewContext
        // (main-queue context), creating a re-entrancy deadlock.
        // The async version properly yields the main actor.
        logger.info("startShareFlow: step 5b — share(_:to:) starting with household '\(freshHousehold.name)'")
        logger.info("startShareFlow: step 5b — objectID: \(freshHousehold.objectID), store: \(freshHousehold.objectID.persistentStore?.configurationName ?? "unknown")")

        // Use a task group for a 30-second timeout safeguard.
        let (share, shareContainer): (CKShare, CKContainer) = try await withThrowingTaskGroup(
            of: (CKShare, CKContainer).self
        ) { group in
            group.addTask { [logger] in
                logger.info("startShareFlow: step 5b — calling async share() NOW")
                let (_, share, container) = try await persistentContainer.share(
                    [freshHousehold], to: nil
                )
                logger.info("startShareFlow: step 5b — async share() returned, URL: \(share.url?.absoluteString ?? "none yet", privacy: .public)")
                return (share, container)
            }

            group.addTask { [logger] in
                try await Task.sleep(for: .seconds(30))
                logger.error("startShareFlow: step 5b — TIMEOUT after 30s")
                throw CloudKitSharingError.timeout
            }

            // Whichever finishes first wins.
            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        // Step 6: Clear applicationVersion so TestFlight recipients aren't blocked.
        await clearApplicationVersion(from: share, using: shareContainer)

        return (share, shareContainer)
    }

    // MARK: - Legacy Entry Point (Deprecated)

    /// Legacy entry point that shares recipes. Use startShareFlow(from:) instead.
    @available(*, deprecated, renamed: "startShareFlow(from:)")
    func prepareShare(
        using persistentContainer: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, CKContainer) {
        try await startShareFlow(from: persistentContainer)
    }

    // MARK: - Existing Share

    /// Returns the active CKShare managed by NSPersistentCloudKitContainer, or nil
    /// if no share has been created yet.
    ///
    /// Also clears `applicationVersion` if UICloudSharingController re-set it during
    /// a previous participant-management interaction.
    func existingShare(using persistentContainer: NSPersistentCloudKitContainer) async -> CKShare? {
        do {
            let shares = try persistentContainer.fetchShares(in: nil)
            guard let share = shares.first else { return nil }

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

    /// Nukes ALL sharing state from CloudKit: CKShare records AND orphaned
    /// share zones. This is the nuclear option for cleaning up after multiple
    /// failed share attempts that leave behind ghost zones.
    ///
    /// Ghost zones (`com.apple.coredata.cloudkit.share.*`) cause:
    /// - "Zone Not Found" import errors (the zone was partially deleted)
    /// - share(_:to:) hangs (the container tries to reconcile stale zone state)
    /// - Rapid syncing↔error flashing in the UI
    ///
    /// This method deletes BOTH the share records AND the orphaned zones,
    /// leaving only `com.apple.coredata.cloudkit.zone` (the main data zone).
    ///
    /// Enforces a 20-second timeout.
    func hardResetSharing(persistentContainer: NSPersistentCloudKitContainer?) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [self] in
                try await self.performHardReset(using: persistentContainer)
            }
            group.addTask {
                try await Task.sleep(for: .seconds(20))
                throw CloudKitSharingError.timeout
            }
            do {
                try await group.next()!
            } catch {
                group.cancelAll()
                throw error
            }
            group.cancelAll()
        }
    }

    /// Cleans up server-side sharing state only — deletes CKShare records AND
    /// orphaned share zones. Does NOT touch local stores.
    ///
    /// Exposed separately from hardResetSharing so the debug UI can offer
    /// "Reset CloudKit Sharing State" as a distinct action from "Reset Local Sync State".
    func cleanupServerSharingState() async throws {
        try await hardResetSharing(persistentContainer: nil)
    }

    private func performHardReset(using persistentContainer: NSPersistentCloudKitContainer?) async throws {
        let db = ckContainer.privateCloudDatabase

        // Step 1: Enumerate all zones in the private database.
        let allZones = try await db.allRecordZones()
        logger.info("Hard reset: found \(allZones.count) zone(s) total")

        // Identify orphaned share zones — these are zones named
        // "com.apple.coredata.cloudkit.share.*" left behind by previous
        // failed share attempts. The main data zone is kept.
        let shareZones = allZones.filter {
            $0.zoneID.zoneName.hasPrefix("com.apple.coredata.cloudkit.share.")
        }
        let mainZone = allZones.first {
            $0.zoneID.zoneName == "com.apple.coredata.cloudkit.zone"
        }

        logger.info("Hard reset: found \(shareZones.count) share zone(s), main zone: \(mainZone != nil ? "present" : "absent")")

        // Step 2: Try to delete share records from each zone (best effort).
        // The query may fail with "Type is not marked indexable" — that's OK,
        // we're going to delete the zones anyway.
        for zone in shareZones {
            do {
                let query = CKQuery(
                    recordType: CKRecord.SystemType.share,
                    predicate: NSPredicate(value: true)
                )
                let (matchResults, _) = try await db.records(
                    matching: query, inZoneWith: zone.zoneID
                )
                let recordIDs = matchResults.compactMap { _, result in try? result.get().recordID }
                if !recordIDs.isEmpty {
                    _ = try await db.modifyRecords(saving: [], deleting: recordIDs)
                    logger.info("Hard reset: deleted \(recordIDs.count) share record(s) from zone \(zone.zoneID.zoneName)")
                }
            } catch {
                logger.info("Hard reset: could not query zone \(zone.zoneID.zoneName) for shares (will delete zone anyway): \(error.localizedDescription, privacy: .public)")
            }
        }

        // Step 3: Also delete any share record found via the container's local metadata.
        if let container = persistentContainer {
            let localShares = (try? container.fetchShares(in: nil)) ?? []
            for share in localShares {
                do {
                    _ = try await db.modifyRecords(saving: [], deleting: [share.recordID])
                    logger.info("Hard reset: deleted local share record \(share.recordID.recordName)")
                } catch {
                    logger.info("Hard reset: failed to delete local share \(share.recordID.recordName): \(error.localizedDescription, privacy: .public)")
                }
            }
        }

        // Step 4: DELETE the orphaned share zones themselves.
        // This is the critical fix — previous code only deleted share records
        // but left the zones behind, causing "Zone Not Found" errors and
        // share(_:to:) hangs.
        if !shareZones.isEmpty {
            let zoneIDs = shareZones.map { $0.zoneID }
            do {
                _ = try await db.modifyRecordZones(saving: [], deleting: zoneIDs)
                logger.info("Hard reset: deleted \(zoneIDs.count) orphaned share zone(s)")
                for zoneID in zoneIDs {
                    logger.info("  deleted zone: \(zoneID.zoneName)")
                }
            } catch {
                // Some zones may already be gone — that's fine.
                logger.warning("Hard reset: zone deletion had errors (some may already be gone): \(error.localizedDescription, privacy: .public)")
            }
        }

        // Step 5: Also check the main data zone for stray share records.
        if let mainZone {
            do {
                let query = CKQuery(
                    recordType: CKRecord.SystemType.share,
                    predicate: NSPredicate(value: true)
                )
                let (matchResults, _) = try await db.records(
                    matching: query, inZoneWith: mainZone.zoneID
                )
                let recordIDs = matchResults.compactMap { _, result in try? result.get().recordID }
                if !recordIDs.isEmpty {
                    _ = try await db.modifyRecords(saving: [], deleting: recordIDs)
                    logger.info("Hard reset: deleted \(recordIDs.count) stray share(s) from main zone")
                }
            } catch {
                logger.info("Hard reset: main zone share query failed (may be OK): \(error.localizedDescription, privacy: .public)")
            }
        }

        logger.info("Hard reset: complete — all share zones and records cleaned up")
    }

    // MARK: - Direct CloudKit query (no container)

    /// Fetches the existing CKShare directly from CloudKit without involving
    /// NSPersistentCloudKitContainer. Used as a fallback when persistentContainer
    /// hasn't been captured yet.
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
                if share["applicationVersion"] as? String != nil {
                    await clearApplicationVersion(from: share, using: ckContainer)
                }
                return share
            }
        }
        return nil
    }

    // MARK: - Private helpers

    /// Clears the `applicationVersion` field from a CKShare and re-saves it.
    func clearApplicationVersion(from share: CKShare, using container: CKContainer) async {
        share["applicationVersion"] = nil as CKRecordValue?
        do {
            _ = try await container.privateCloudDatabase.modifyRecords(saving: [share], deleting: [])
            logger.info("Cleared applicationVersion from share.")
        } catch {
            logger.warning("Could not clear applicationVersion: \(error.localizedDescription)")
        }
    }

    // MARK: - User Identity

    /// Fetches the current user's iCloud display name.
    func fetchCurrentUserDisplayName() async -> String? {
        do {
            let recordID = try await ckContainer.userRecordID()
            let lookupInfo = CKUserIdentity.LookupInfo(userRecordID: recordID)

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
    case noHouseholdToShare
    case householdInWrongStore
    case exportNotReady
    case shareFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            "iCloud account is not available — sign in to share recipes"
        case .noRecipesToShare:
            "Add at least one recipe before sharing your library"
        case .noHouseholdToShare:
            "No household found — the app needs at least one household to share"
        case .householdInWrongStore:
            "Household is in the shared store — try resetting local sync state first"
        case .exportNotReady:
            "iCloud hasn't finished its initial sync yet — wait a moment and try again"
        case .shareFailed:
            "CloudKit did not return a valid share — please try again"
        case .timeout:
            "Sharing timed out — try 'Reset Local Sync State' in Debug settings, then share again"
        }
    }
}
