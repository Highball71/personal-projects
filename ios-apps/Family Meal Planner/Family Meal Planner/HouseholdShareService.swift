//
//  HouseholdShareService.swift
//  Family Meal Planner
//
//  Manages CloudKit sharing for the household.
//  Uses NSPersistentCloudKitContainer's native share API directly —
//  no SwiftData bridging, no manual CloudKit record manipulation.
//

import CloudKit
import CoreData
import UIKit
import os

@MainActor
final class HouseholdShareService {
    static let shared = HouseholdShareService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.FamilyMealPlanner",
        category: "Sharing"
    )

    private init() {}

    // MARK: - Account Check

    /// Returns true if the user is signed into iCloud.
    func isCloudKitAvailable() async -> Bool {
        do {
            let status = try await PersistenceController.shared.ckContainer.accountStatus()
            return status == .available
        } catch {
            logger.warning("Could not check iCloud status: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Share Household

    /// Creates a new CKShare for the given household object.
    ///
    /// This calls `NSPersistentCloudKitContainer.share(_:to:completion:)` directly,
    /// which is the supported API for sharing Core Data objects via CloudKit.
    /// The container handles all the zone/record/share plumbing internally.
    ///
    /// - Parameter household: The CDHousehold managed object to share.
    /// - Returns: A tuple of (CKShare, CKContainer) ready for UICloudSharingController.
    func shareHousehold(_ household: CDHousehold) async throws -> (CKShare, CKContainer) {
        guard await isCloudKitAvailable() else {
            throw HouseholdShareError.accountNotAvailable
        }

        let container = PersistenceController.shared.container

        logger.info("shareHousehold: starting share for household '\(household.name)'")

        // Use withCheckedThrowingContinuation to bridge the callback-based API.
        let (share, ckContainer) = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(CKShare, CKContainer), Error>) in

            // share(_:to:completion:) — pass nil for `to:` to create a NEW share.
            // Do NOT pass an existing share. Do NOT manually delete old shares.
            container.share([household], to: nil) { _, share, ckContainer, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let share, let ckContainer {
                    continuation.resume(returning: (share, ckContainer))
                } else {
                    continuation.resume(throwing: HouseholdShareError.shareFailed)
                }
            }
        }

        // Set the share title for better UX in the sharing UI.
        share[CKShare.SystemFieldKey.title] = household.name as CKRecordValue

        logger.info("shareHousehold: share created. URL: \(share.url?.absoluteString ?? "none yet")")
        return (share, ckContainer)
    }

    // MARK: - Check for Existing Share

    /// Returns the existing CKShare for the household, if one exists.
    func existingShare(for household: CDHousehold) -> CKShare? {
        let container = PersistenceController.shared.container
        guard let shares = try? container.fetchShares(in: nil) else {
            return nil
        }
        // Find the share that covers this household's record.
        // fetchShares(matching:) is also available but fetchShares(in:)
        // is simpler when there's only one share.
        return shares.first
    }

    // MARK: - Create UICloudSharingController

    /// Returns a configured UICloudSharingController for sharing the household.
    /// If a share already exists, it returns a controller for managing participants.
    /// If no share exists, it creates one.
    func makeSharingController(for household: CDHousehold) async throws -> UICloudSharingController {
        if let existingShare = existingShare(for: household) {
            // Share already exists — return a controller to manage participants.
            let controller = UICloudSharingController(share: existingShare,
                                                       container: PersistenceController.shared.ckContainer)
            controller.availablePermissions = [.allowReadWrite, .allowPrivate, .allowPublic]
            return controller
        }

        // No share yet — create one.
        let (share, ckContainer) = try await shareHousehold(household)
        let controller = UICloudSharingController(share: share, container: ckContainer)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate, .allowPublic]
        return controller
    }
}

// MARK: - Errors

enum HouseholdShareError: LocalizedError {
    case accountNotAvailable
    case noHousehold
    case shareFailed

    var errorDescription: String? {
        switch self {
        case .accountNotAvailable:
            return "iCloud account is not available. Please sign in to iCloud in Settings."
        case .noHousehold:
            return "No household found. Please create a household first."
        case .shareFailed:
            return "Failed to create share. Please try again."
        }
    }
}
