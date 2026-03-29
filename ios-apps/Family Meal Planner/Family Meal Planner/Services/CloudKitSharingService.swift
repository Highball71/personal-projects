//
//  CloudKitSharingService.swift
//  Family Meal Planner
//
//  THE single source of truth for CloudKit sharing.
//  Uses ZONE-LEVEL sharing: one CKShare covers the entire private
//  CloudKit zone, so every entity syncs to share participants
//  automatically — no need to wire relationship graphs.
//

import CloudKit
import CoreData
import os.log

/// Manages CloudKit sharing for the household recipe library.
///
/// Instead of sharing a specific CDHousehold object (which requires every entity
/// to be reachable via relationships), we share the ENTIRE default private zone.
/// This means all records — recipes, ingredients, meal plans, grocery items,
/// household members — are automatically included in the share.
///
/// Flow:
/// 1. Head Cook taps "Share" -> `startShareFlow(from:)`
/// 2. If no zone-level CKShare exists, one is created via the CloudKit API
/// 3. UICloudSharingController presents the system sharing UI
/// 4. Head Cook sends the share URL (e.g. via iMessage)
/// 5. Recipient taps the link -> AppDelegate accepts it -> CloudKit syncs
@MainActor
final class CloudKitSharingService {
    static let shared = CloudKitSharingService()

    /// The CloudKit container identifier (matches entitlements).
    nonisolated static let containerIdentifier = "iCloud.com.highball71.FamilyMealPlanner"

    /// The zone name Core Data uses for its private database records.
    private static let coreDataZoneName = "com.apple.coredata.cloudkit.zone"

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

    /// The primary sharing entry point. Returns an existing zone-level share,
    /// or creates a new one covering the entire Core Data private zone.
    ///
    /// This replaces the old object-level approach. Zone-level sharing means:
    /// - Every entity is included automatically (no relationship graph needed)
    /// - No ghost share zones (there's only one zone, not one per attempt)
    /// - No need to find/fetch a CDHousehold root object
    ///
    /// - Parameters:
    ///   - persistentContainer: The NSPersistentCloudKitContainer.
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

        // Step 1: Wait for at least one successful export cycle.
        // Objects must be exported to CloudKit before the zone can be shared.
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

        // Step 2: Check for an existing zone-level share.
        if let existing = try await fetchExistingZoneShare() {
            logger.info("startShareFlow: reusing existing zone share (URL: \(existing.url?.absoluteString ?? "none", privacy: .public))")
            await clearApplicationVersion(from: existing, using: ckContainer)
            return (existing, ckContainer)
        }

        // Step 3: Create a new zone-level share.
        logger.info("startShareFlow: creating new zone-level share")
        let zoneID = CKRecordZone.ID(
            zoneName: Self.coreDataZoneName,
            ownerName: CKCurrentUserDefaultName
        )
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "Family Meal Planner" as CKRecordValue

        // Save the share to CloudKit with a 30-second timeout.
        let savedShare: CKShare = try await withThrowingTaskGroup(of: CKShare.self) { group in
            group.addTask { [logger, ckContainer] in
                logger.info("startShareFlow: saving zone share to CloudKit")
                let db = ckContainer.privateCloudDatabase
                let (saveResults, _) = try await db.modifyRecords(
                    saving: [share], deleting: []
                )
                // Extract the saved CKShare from the results.
                guard let savedResult = saveResults[share.recordID],
                      let saved = try? savedResult.get() as? CKShare else {
                    throw CloudKitSharingError.shareFailed
                }
                logger.info("startShareFlow: zone share saved (URL: \(saved.url?.absoluteString ?? "none", privacy: .public))")
                return saved
            }

            group.addTask { [logger] in
                try await Task.sleep(for: .seconds(30))
                logger.error("startShareFlow: TIMEOUT after 30s")
                throw CloudKitSharingError.timeout
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }

        await clearApplicationVersion(from: savedShare, using: ckContainer)
        return (savedShare, ckContainer)
    }

    // MARK: - Existing Share

    /// Returns the active zone-level CKShare, or nil if none exists.
    ///
    /// Checks the container's local metadata first (fast), then falls back
    /// to querying CloudKit directly.
    func existingShare(using persistentContainer: NSPersistentCloudKitContainer) async -> CKShare? {
        // Try local metadata first.
        if let shares = try? persistentContainer.fetchShares(in: nil),
           let share = shares.first {
            if share["applicationVersion"] as? String != nil {
                await clearApplicationVersion(from: share, using: ckContainer)
            }
            return share
        }
        // Fall back to direct CloudKit query.
        return try? await fetchExistingZoneShare()
    }

    /// Fetches the existing zone-level CKShare directly from CloudKit.
    /// Returns nil if no share exists in the Core Data zone.
    ///
    /// Uses a direct record fetch with `CKRecordNameZoneWideShare` instead
    /// of a CKQuery. CKQuery requires the `cloudkit.share` type to be marked
    /// indexable in the CloudKit schema — which it isn't by default — causing
    /// "type is not marked indexable" at runtime.
    func fetchExistingZoneShare() async throws -> CKShare? {
        let db = ckContainer.privateCloudDatabase
        let zoneID = CKRecordZone.ID(
            zoneName: Self.coreDataZoneName,
            ownerName: CKCurrentUserDefaultName
        )

        // Zone-level shares use a well-known record name.
        let shareRecordID = CKRecord.ID(
            recordName: CKRecordNameZoneWideShare,
            zoneID: zoneID
        )

        do {
            let record = try await db.record(for: shareRecordID)
            guard let share = record as? CKShare else { return nil }
            if share["applicationVersion"] as? String != nil {
                await clearApplicationVersion(from: share, using: ckContainer)
            }
            return share
        } catch let error as CKError where error.code == .unknownItem {
            // No zone-level share exists yet.
            return nil
        }
    }

    // MARK: - Delete Share

    /// Deletes the zone-level share from CloudKit. Does NOT delete the zone
    /// or any data — just removes the sharing relationship.
    func deleteShare() async throws {
        guard let share = try await fetchExistingZoneShare() else {
            logger.info("deleteShare: no share to delete")
            return
        }
        let db = ckContainer.privateCloudDatabase
        _ = try await db.modifyRecords(saving: [], deleting: [share.recordID])
        logger.info("deleteShare: zone share deleted")
    }

    // MARK: - Private helpers

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
