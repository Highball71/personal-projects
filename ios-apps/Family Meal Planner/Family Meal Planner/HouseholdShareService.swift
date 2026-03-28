//
//  HouseholdShareService.swift
//  Family Meal Planner
//
//  DEPRECATED — This is the older sharing approach.
//  All sharing logic is now consolidated in CloudKitSharingService.swift.
//  This file is kept only to avoid breaking any remaining references.
//  Do NOT call any methods in this file for new code.
//

import CloudKit
import CoreData
import UIKit
import os

/// DEPRECATED: Use CloudKitSharingService.shared instead.
///
/// This was the original sharing service that used PersistenceController.shared
/// directly. It has been superseded by CloudKitSharingService which:
/// - Uses the SyncMonitor-captured container (not the static shared one)
/// - Shares CDHousehold as the root object (not individual recipes)
/// - Supports container rebuilds after local store resets
/// - Handles stale share cleanup and applicationVersion clearing
@available(*, deprecated, message: "Use CloudKitSharingService.shared.startShareFlow(from:) instead")
@MainActor
final class HouseholdShareService {
    static let shared = HouseholdShareService()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.FamilyMealPlanner",
        category: "Sharing"
    )

    private init() {}

    // MARK: - Account Check

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

    func shareHousehold(_ household: CDHousehold) async throws -> (CKShare, CKContainer) {
        guard await isCloudKitAvailable() else {
            throw HouseholdShareError.accountNotAvailable
        }

        let container = PersistenceController.shared.container

        logger.info("shareHousehold: starting share for household '\(household.name)'")

        let (share, ckContainer) = try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<(CKShare, CKContainer), Error>) in

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

        share[CKShare.SystemFieldKey.title] = household.name as CKRecordValue

        logger.info("shareHousehold: share created. URL: \(share.url?.absoluteString ?? "none yet")")
        return (share, ckContainer)
    }

    // MARK: - Check for Existing Share

    func existingShare(for household: CDHousehold) -> CKShare? {
        let container = PersistenceController.shared.container
        guard let shares = try? container.fetchShares(in: nil) else {
            return nil
        }
        return shares.first
    }

    // MARK: - Create UICloudSharingController

    func makeSharingController(for household: CDHousehold) async throws -> UICloudSharingController {
        if let existingShare = existingShare(for: household) {
            let controller = UICloudSharingController(share: existingShare,
                                                       container: PersistenceController.shared.ckContainer)
            controller.availablePermissions = [.allowReadWrite, .allowPrivate, .allowPublic]
            return controller
        }

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
