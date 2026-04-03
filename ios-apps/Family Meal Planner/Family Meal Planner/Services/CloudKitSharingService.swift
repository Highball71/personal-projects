//
//  CloudKitSharingService.swift
//  Family Meal Planner
//
//  Clean object-level CloudKit sharing using CDHousehold as the root shared object.
//

import CloudKit
import CoreData
import os.log

@MainActor
final class CloudKitSharingService {
    static let shared = CloudKitSharingService()

    nonisolated static let containerIdentifier = "iCloud.com.highball71.FamilyMealPlanner"

    private let ckContainer: CKContainer
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.FamilyMealPlanner",
        category: "Sharing"
    )

    private init() {
        ckContainer = CKContainer(identifier: Self.containerIdentifier)
    }

    // MARK: - Account

    func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await ckContainer.accountStatus()
            return status == .available
        } catch {
            logger.warning("Could not check iCloud status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Share Flow

    func startShareFlow(
        household: CDHousehold,
        container: NSPersistentCloudKitContainer,
        syncMonitor: SyncMonitor? = nil,
        forceNewShare: Bool = false
    ) async throws -> (CKShare, CKContainer) {
        logger.info("startShareFlow: entered (forceNewShare=\(forceNewShare))")

        guard await isCloudKitAvailable() else {
            throw CloudKitSharingError.accountNotAvailable
        }

        // Optional: wait briefly for at least one export cycle if the app is still starting up.
        if let syncMonitor, !syncMonitor.hasCompletedExport {
            logger.info("startShareFlow: waiting for initial export")
            for _ in 0..<20 {
                guard !Task.isCancelled else { throw CancellationError() }
                if syncMonitor.hasCompletedExport { break }
                try await Task.sleep(for: .milliseconds(500))
            }
        }

        // Make sure the household is fully persisted before sharing.
        try prepareForSharing(household: household, in: container.viewContext)

        // Delete existing share first if forcing a new one.
        if forceNewShare {
            if let existing = existingShare(for: household, container: container) {
                logger.info("startShareFlow: forceNewShare — deleting existing share (recordID=\(existing.recordID))")
                do {
                    let db = ckContainer.privateCloudDatabase
                    _ = try await db.modifyRecords(saving: [], deleting: [existing.recordID])
                    logger.info("startShareFlow: forceNewShare — server-side share deleted")
                    // Brief pause for Core Data mirror to process the deletion.
                    try await Task.sleep(for: .seconds(2))
                } catch {
                    logger.warning("startShareFlow: forceNewShare — delete failed: \(error.localizedDescription), proceeding with new share anyway")
                }
            } else {
                logger.info("startShareFlow: forceNewShare — no existing share found")
            }
        }

        // Reuse an existing share if one already exists (skipped when forceNewShare).
        if !forceNewShare, let existing = existingShare(for: household, container: container) {
            let participantCount = existing.participants.count
            let hasURL = existing.url != nil
            logger.info("startShareFlow: reusing existing share (recordID=\(existing.recordID), participants=\(participantCount), hasURL=\(hasURL), url=\(existing.url?.absoluteString ?? "nil", privacy: .public))")
            await clearApplicationVersion(from: existing, using: ckContainer)
            return (existing, ckContainer)
        }
        
        logger.info("startShareFlow: creating new share")

        let share = try await createShareWithTimeout(
            for: household,
            container: container,
            timeoutNanoseconds: 15_000_000_000
        )

        share[CKShare.SystemFieldKey.title] = "Family Meal Planner" as CKRecordValue
        await clearApplicationVersion(from: share, using: ckContainer)

        return (share, ckContainer)
    }

    // MARK: - Existing Share Lookup

    func existingShare(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer
    ) -> CKShare? {
        do {
            let shares = try container.fetchShares(matching: [household.objectID])
            return shares[household.objectID]
        } catch {
            logger.warning("existingShare failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Delete Share

    func deleteShare(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer
    ) async throws {
        guard let share = existingShare(for: household, container: container) else {
            logger.info("deleteShare: no share to delete")
            return
        }

        let db = ckContainer.privateCloudDatabase
        _ = try await db.modifyRecords(saving: [], deleting: [share.recordID])
        logger.info("deleteShare: household share deleted")
    }

    // MARK: - Nuclear Share Reset

    /// Deletes ALL CKShare records from the private database zone used by
    /// NSPersistentCloudKitContainer, waits for the mirror to settle, then
    /// creates a brand-new share on the existing (stable) container.
    /// Does NOT touch local stores or rebuild the container.
    func nuclearShareReset(
        household: CDHousehold,
        container: NSPersistentCloudKitContainer,
        syncMonitor: SyncMonitor? = nil
    ) async throws -> (CKShare, CKContainer) {
        logger.info("nuclearShareReset: === STARTING ===")

        // 1. Log the old share state.
        let oldShare = existingShare(for: household, container: container)
        let oldRecordID = oldShare?.recordID.recordName ?? "none"
        let oldURL = oldShare?.url?.absoluteString ?? "none"
        logger.info("nuclearShareReset: old share recordID=\(oldRecordID, privacy: .public), oldURL=\(oldURL, privacy: .public)")

        // 2. Delete via CKDatabase (server-side).
        if let share = oldShare {
            logger.info("nuclearShareReset: deleting old share from server")
            do {
                let db = ckContainer.privateCloudDatabase
                _ = try await db.modifyRecords(saving: [], deleting: [share.recordID])
                logger.info("nuclearShareReset: server delete succeeded")
            } catch {
                logger.error("nuclearShareReset: server delete failed: \(error.localizedDescription, privacy: .public)")
                // Continue anyway — the share may already be gone server-side.
            }
        } else {
            logger.info("nuclearShareReset: no local share found to delete")
        }

        // 3. Also try to purge any zone-level shares we missed.
        do {
            let db = ckContainer.privateCloudDatabase
            let zone = CKRecordZone(zoneName: "com.apple.coredata.cloudkit.zone")
            let allRecords = try await db.records(matching: CKQuery(
                recordType: "cloudkit.share",
                predicate: NSPredicate(value: true)
            ), inZoneWith: zone.zoneID)
            let shareIDs = allRecords.matchResults.map { $0.0 }
            if !shareIDs.isEmpty {
                logger.info("nuclearShareReset: found \(shareIDs.count) zone share record(s) to delete")
                _ = try await db.modifyRecords(saving: [], deleting: shareIDs)
                logger.info("nuclearShareReset: zone share records deleted")
            } else {
                logger.info("nuclearShareReset: no zone share records found")
            }
        } catch {
            logger.warning("nuclearShareReset: zone share cleanup failed: \(error.localizedDescription, privacy: .public)")
        }

        // 4. Wait for Core Data mirror to process the deletion.
        logger.info("nuclearShareReset: waiting 5s for mirror to settle")
        try await Task.sleep(for: .seconds(5))

        // 5. Check if the local mirror still sees a share.
        let ghostShare = existingShare(for: household, container: container)
        if let ghost = ghostShare {
            logger.warning("nuclearShareReset: ghost share still exists locally (recordID=\(ghost.recordID.recordName, privacy: .public)) — proceeding anyway")
        } else {
            logger.info("nuclearShareReset: local share cleared successfully")
        }

        // 6. Create a brand-new share on the existing stable container.
        logger.info("nuclearShareReset: creating new share")
        let newShare = try await createShareWithTimeout(
            for: household,
            container: container,
            timeoutNanoseconds: 15_000_000_000
        )

        let newRecordID = newShare.recordID.recordName
        let newURL = newShare.url?.absoluteString ?? "none"
        logger.info("nuclearShareReset: === NEW SHARE CREATED === recordID=\(newRecordID, privacy: .public), url=\(newURL, privacy: .public)")

        // 7. Compare old vs new.
        if oldURL == newURL && oldURL != "none" {
            logger.error("nuclearShareReset: WARNING — new URL is identical to old URL!")
        }

        newShare[CKShare.SystemFieldKey.title] = "Family Meal Planner" as CKRecordValue
        await clearApplicationVersion(from: newShare, using: ckContainer)

        return (newShare, ckContainer)
    }

    // MARK: - Private Helpers

    private func prepareForSharing(
        household: CDHousehold,
        in context: NSManagedObjectContext
    ) throws {

        if household.objectID.isTemporaryID {
            try context.obtainPermanentIDs(for: [household])
        }

        if let recipes = household.recipes as? Set<CDRecipe> {
            for recipe in recipes {
                recipe.household = household

                if recipe.objectID.isTemporaryID {
                    try context.obtainPermanentIDs(for: [recipe])
                }

                if let mealPlans = recipe.mealPlans as? Set<CDMealPlan> {
                    for mealPlan in mealPlans {
                        mealPlan.recipe = recipe

                        if mealPlan.objectID.isTemporaryID {
                            try context.obtainPermanentIDs(for: [mealPlan])
                        }
                    }
                }
            }
        }

        let groceryRequest: NSFetchRequest<CDGroceryItem> = CDGroceryItem.fetchRequest()
        groceryRequest.predicate = NSPredicate(format: "household == %@", household)

        let groceryItems = try context.fetch(groceryRequest)
        for item in groceryItems {
            item.household = household

            if item.objectID.isTemporaryID {
                try context.obtainPermanentIDs(for: [item])
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }
    
    
    private func createShareWithTimeout(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer,
        timeoutNanoseconds: UInt64
    ) async throws -> CKShare {
        logger.info("createShareWithTimeout: entered (timeout=\(timeoutNanoseconds / 1_000_000_000)s)")
        let result = try await withThrowingTaskGroup(of: CKShare.self) { group in
            group.addTask {
                self.logger.info("createShareWithTimeout: share task started")
                return try await self.createShare(for: household, container: container)
            }

            group.addTask {
                self.logger.info("createShareWithTimeout: timeout task started")
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                self.logger.warning("createShareWithTimeout: TIMEOUT fired after \(timeoutNanoseconds / 1_000_000_000)s")
                throw CloudKitSharingError.timeout
            }

            logger.info("createShareWithTimeout: waiting on group.next()")
            let result = try await group.next()!
            logger.info("createShareWithTimeout: group.next() returned")
            group.cancelAll()
            return result
        }

        return result
    }

    private func createShare(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer
    ) async throws -> CKShare {
        logger.info("createShare: started")

        return try await withCheckedThrowingContinuation { continuation in
            container.share([household], to: nil) { _, share, _, error in
                self.logger.info("createShare completion fired: shareNil=\(share == nil), errorNil=\(error == nil)")
                if let error {
                    self.logger.error("createShare failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let share {
                    self.logger.info("createShare: success")
                    continuation.resume(returning: share)
                } else {
                    self.logger.error("createShare: no share returned")
                    continuation.resume(throwing: CloudKitSharingError.shareFailed)
                }
            }
        }
    }

    func clearApplicationVersion(from share: CKShare, using container: CKContainer) async {
        share["applicationVersion"] = nil as CKRecordValue?

        do {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [share],
                deleting: []
            )
            logger.info("Cleared applicationVersion from share")
        } catch {
            logger.warning("Could not clear applicationVersion: \(error.localizedDescription)")
        }
    }

    // MARK: - User Identity

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
                        let name = formatter.string(from: components)
                        if !name.isEmpty {
                            fetchedName = name
                        }
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

enum CloudKitSharingError: LocalizedError {
    case accountNotAvailable
    case noHouseholdToShare
    case exportNotReady
    case shareFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available — sign in to share recipes"
        case .noHouseholdToShare:
            return "No household found — the app needs at least one household to share"
        case .exportNotReady:
            return "iCloud hasn't finished its initial sync yet — wait a moment and try again"
        case .shareFailed:
            return "CloudKit did not return a valid share — please try again"
        case .timeout:
            return "Sharing timed out — please try again in a moment"
        }
    }
}
