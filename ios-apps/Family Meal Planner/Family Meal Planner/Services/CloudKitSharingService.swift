//
//  CloudKitSharingService.swift
//  Family Meal Planner
//
//  THE single source of truth for CloudKit sharing.
//  Uses OBJECT-LEVEL sharing: a CDHousehold is the root shared object.
//  All entities reachable via relationships (recipes, ingredients,
//  meal plans, ratings, suggestions, members, grocery items) are
//  automatically included in the share by Core Data.
//

import CloudKit
import CoreData
import os.log

/// Manages CloudKit sharing for the household recipe library.
///
/// Shares a single CDHousehold object using NSPersistentCloudKitContainer's
/// object-sharing API. Because every entity is reachable from CDHousehold
/// via relationships, Core Data automatically includes the full object graph
/// in the share.
///
/// Flow:
/// 1. Head Cook taps "Share" -> `startShareFlow(household:container:)`
/// 2. If an existing CKShare is found for the household, reuse it
/// 3. Otherwise create a new share via `container.share(_:to:completion:)`
/// 4. UICloudSharingController presents the system sharing UI
/// 5. Head Cook sends the share URL (e.g. via iMessage)
/// 6. Recipient taps the link -> AppDelegate accepts it -> CloudKit syncs
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

    // MARK: - Object-Level Share Flow

    /// The primary sharing entry point. Returns an existing share for the
    /// household, or creates a new one using Core Data's object-sharing API.
    ///
    /// - Parameters:
    ///   - household: The CDHousehold root object to share.
    ///   - container: The NSPersistentCloudKitContainer that owns the store.
    ///   - syncMonitor: Optional SyncMonitor to check if at least one export
    ///     has completed. Objects must be exported before they can be shared.
    /// - Returns: (CKShare, CKContainer) ready for UICloudSharingController.
 
    func startShareFlow(
        household: CDHousehold,
        container: NSPersistentCloudKitContainer,
        syncMonitor: SyncMonitor? = nil
    ) async throws -> (CKShare, CKContainer) {
        logger.info("🚀 startShareFlow: entered")
        guard await isCloudKitAvailable() else {
            
            throw CloudKitSharingError.accountNotAvailable
        }
        logger.info("🔍 Checking for existing share")
        // Wait for at least one successful export cycle.
        // Objects must be exported to CloudKit before they can be shared.
        if let syncMonitor, !syncMonitor.hasCompletedExport {
            logger.info("startShareFlow: waiting for initial export to complete")
            for i in 0..<30 {
                guard !Task.isCancelled else { throw CancellationError() }
                try await Task.sleep(for: .milliseconds(500))
                if syncMonitor.hasCompletedExport {
                    logger.info("startShareFlow: export completed after \(i * 500)ms")
                    break
                }
            }
            if !syncMonitor.hasCompletedExport {
                logger.error("startShareFlow: no successful export after 15s")
                throw CloudKitSharingError.exportNotReady
            }
        }
        logger.info("🔍 Checking for existing share")
        
        // Check for an existing share on this household.
        // TEMP: disable share reuse (force clean share)
        logger.info("🚫 Skipping existing share — forcing new share")
        // Create a new share for the household object.
        logger.info("startShareFlow: creating new object-level share for household")
        logger.info("📡 Calling createShare()")
        
        let result = try await withThrowingTaskGroup(of: (CKShare, NSPersistentContainer).self) { group in
            group.addTask {
                try await self.createShare(for: household, container: container)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                self.logger.error("⏰ Share creation timed out after 15s")
                throw CloudKitSharingError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
        
        let (share, _) = result
        share[CKShare.SystemFieldKey.title] = "Family Meal Planner" as CKRecordValue
        await clearApplicationVersion(from: share, using: self.ckContainer)
        return (share, self.ckContainer)
    }

    // MARK: - Existing Share Lookup

    /// Returns the active CKShare for a household, or nil if none exists.
    ///
    /// Uses Core Data's `fetchShares(matching:)` keyed by the household's
    /// objectID to find the share metadata locally.
    func existingShare(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer
    ) -> CKShare? {
        guard let shares = try? container.fetchShares(matching: [household.objectID]),
              let share = shares[household.objectID] else {
            return nil
        }
        return share
    }

    // MARK: - Delete Share

    /// Deletes the share for the given household.
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

    // MARK: - Private helpers

    /// Creates a new CKShare for the household using Core Data's sharing API.
    private func createShare(
        for household: CDHousehold,
        container: NSPersistentCloudKitContainer
    ) async throws -> (CKShare, NSPersistentContainer) {
        logger.info("📡 createShare: started")
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(CKShare, NSPersistentCloudKitContainer), Error>) in            container.share([household], to: nil) { objectIDs, share, ckContainer, error in
                if let error {
                    self.logger.error("❌ createShare failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else if let share {
                    self.logger.info("✅ createShare success")
                    continuation.resume(returning: (share, container))
                } else {
                    self.logger.error("❌ createShare: no share returned")
                    continuation.resume(throwing: CloudKitSharingError.shareFailed)
                }
            }
        }
    }

    /// Clears the `applicationVersion` field from a CKShare and re-saves it.
    /// TestFlight builds set this, which can block share acceptance for
    /// recipients running a different build number.
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
    case noHouseholdToShare
    case exportNotReady
    case shareFailed
    case timeout

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            "iCloud account is not available — sign in to share recipes"
        case .noHouseholdToShare:
            "No household found — the app needs at least one household to share"
        case .exportNotReady:
            "iCloud hasn't finished its initial sync yet — wait a moment and try again"
        case .shareFailed:
            "CloudKit did not return a valid share — please try again"
        case .timeout:
            "Sharing timed out — please try again in a moment"
        }
    }
}
