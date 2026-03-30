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
        syncMonitor: SyncMonitor? = nil
    ) async throws -> (CKShare, CKContainer) {
        logger.info("startShareFlow: entered")

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

        // Reuse an existing share if one already exists.
        if let existing = existingShare(for: household, container: container) {
            logger.info("startShareFlow: deleting stale existing share before creating a new one")
            try? await deleteShare(for: household, container: container)
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

    // MARK: - Private Helpers

    private func prepareForSharing(
        household: CDHousehold,
        in context: NSManagedObjectContext
    ) throws {

        // 1. Ensure permanent ID
        if household.objectID.isTemporaryID {
            try context.obtainPermanentIDs(for: [household])
            logger.info("prepareForSharing: obtained permanent household ID")
        }

        // 2. Walk ALL related objects and ensure they belong to household
        if let recipes = household.recipes as? Set<CDRecipe> {
            for recipe in recipes {
                recipe.household = household

                if recipe.objectID.isTemporaryID {
                    try context.obtainPermanentIDs(for: [recipe])
                }
            }
        }

        // 3. Force full save chain
        if context.hasChanges {
            try context.save()
            logger.info("prepareForSharing: saved context before sharing")
        }

        // 4. CRITICAL: refresh objects so faults are resolved
        context.refreshAllObjects()
    }
    private func createShareWithTimeout(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer,
        timeoutNanoseconds: UInt64
    ) async throws -> CKShare {
        let result = try await withThrowingTaskGroup(of: CKShare.self) { group in
            group.addTask {
                try await self.createShare(for: household, container: container)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw CloudKitSharingError.timeout
            }

            let result = try await group.next()!
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
