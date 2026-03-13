//
//  CloudKitSharingService.swift
//  FluffyList
//
//  Manages CloudKit sharing so all household members access one recipe library.
//

import CloudKit
import os.log

/// Manages CloudKit sharing for the household recipe library.
///
/// SwiftData syncs all @Model objects to a private CloudKit zone. This service
/// creates a zone-wide CKShare for that zone, which shares ALL records (recipes,
/// meal plans, grocery items, ratings, suggestions, and members) with invited
/// household members.
///
/// Flow:
/// 1. Head Cook calls `createHouseholdShare()` to get a share URL
/// 2. Send the URL to household members (Messages, AirDrop, etc.)
/// 3. Members tap the link → AppDelegate accepts the share
/// 4. SwiftData automatically syncs shared records to their devices
actor CloudKitSharingService {
    static let shared = CloudKitSharingService()

    /// The CloudKit container identifier (matches entitlements).
    static nonisolated let containerIdentifier = "iCloud.com.highball71.FamilyMealPlanner"

    private let container: CKContainer
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.fluffylist",
        category: "Sharing"
    )

    /// The zone that NSPersistentCloudKitContainer (backing SwiftData) uses
    /// for syncing @Model objects.
    private let swiftDataZoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    private init() {
        container = CKContainer(identifier: Self.containerIdentifier)
    }

    // MARK: - Account

    /// Checks whether the user is signed into iCloud.
    func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            logger.warning("Could not check iCloud status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Zone-Wide Sharing

    /// Creates a zone-wide CKShare for the SwiftData zone.
    /// This shares the entire recipe library — all models in the zone —
    /// with anyone who accepts the link.
    ///
    /// - Returns: The share URL to send to household members.
    /// - Throws: `CloudKitSharingError` or `CKError` if the share fails.
    func createHouseholdShare() async throws -> URL {
        guard await isCloudKitAvailable() else {
            throw CloudKitSharingError.accountNotAvailable
        }

        // Create a zone-wide share (iOS 15+).
        // Covers ALL records in the zone — recipes, ingredients,
        // meal plans, grocery items, ratings, suggestions, and members.
        let share = CKShare(recordZoneID: swiftDataZoneID)
        share[CKShare.SystemFieldKey.title] = "FluffyList Recipes" as CKRecordValue
        share.publicPermission = .readWrite

        let (saveResults, _) = try await container.privateCloudDatabase.modifyRecords(
            saving: [share],
            deleting: []
        )

        // Check for per-record errors.
        for (recordID, result) in saveResults {
            if case .failure(let error) = result {
                logger.error("Failed to save share \(recordID): \(error.localizedDescription)")
                throw error
            }
        }

        guard let shareURL = share.url else {
            throw CloudKitSharingError.noShareURL
        }

        logger.info("Created household share: \(shareURL.absoluteString)")
        return shareURL
    }

    /// Fetches the existing household share URL, if one has already been created.
    /// Returns nil if no share exists yet (expected for first-time setup).
    func existingShareURL() async -> URL? {
        let shareRecordID = CKRecord.ID(
            recordName: CKRecordNameZoneWideShare,
            zoneID: swiftDataZoneID
        )
        do {
            let record = try await container.privateCloudDatabase.record(for: shareRecordID)
            return (record as? CKShare)?.url
        } catch let error as CKError where error.code == .unknownItem {
            // No share exists yet — this is expected.
            return nil
        } catch {
            logger.warning("Could not fetch existing share: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - User Identity

    /// Fetches the current user's iCloud display name using the modern
    /// `CKFetchShareParticipantsOperation` API (replaces the deprecated
    /// `CKContainer.discoverUserIdentity` removed in iOS 17).
    ///
    /// Flow: get the current user's record ID → wrap it in a lookup info →
    /// run a fetch-participants operation → read `nameComponents` from the
    /// returned `CKShare.Participant.userIdentity`.
    ///
    /// Returns nil when the user hasn't enabled iCloud discoverability,
    /// is not signed in, or a network error occurs.
    func fetchCurrentUserDisplayName() async -> String? {
        do {
            let recordID = try await container.userRecordID()
            let lookupInfo = CKUserIdentity.LookupInfo(userRecordID: recordID)

            // CKFetchShareParticipantsOperation has no native async overload —
            // wrap with a checked continuation.
            let name: String? = try await withCheckedThrowingContinuation { continuation in
                var fetchedName: String? = nil

                let operation = CKFetchShareParticipantsOperation(
                    userIdentityLookupInfos: [lookupInfo]
                )
                operation.qualityOfService = .userInitiated

                // perShareParticipantResultBlock (iOS 15+) supersedes the
                // deprecated shareParticipantFetchedBlock. Swift renames the
                // NS_REFINED_FOR_SWIFT Obj-C property to this Result-typed form.
                operation.perShareParticipantResultBlock = { _, result in
                    if case .success(let participant) = result,
                       let components = participant.userIdentity.nameComponents {
                        let formatter = PersonNameComponentsFormatter()
                        formatter.style = .default
                        let n = formatter.string(from: components)
                        if !n.isEmpty { fetchedName = n }
                    }
                }

                // Called when all lookups finish (success or failure).
                operation.fetchShareParticipantsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume(returning: fetchedName)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                container.add(operation)
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
    case noShareURL
    case accountNotAvailable

    var errorDescription: String? {
        switch self {
        case .noShareURL:
            "CloudKit did not return a share URL"
        case .accountNotAvailable:
            "iCloud account is not available — sign in to share recipes"
        }
    }
}
