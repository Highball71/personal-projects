//
//  ShareCoordinator.swift
//  Family Meal Planner
//
//  UICloudSharingControllerDelegate implementation.
//  Logs share save/failure/stop events for debugging.
//

import CloudKit
import UIKit
import os

final class ShareCoordinator: NSObject, UICloudSharingControllerDelegate {
    static let shared = ShareCoordinator()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.highball71.FamilyMealPlanner",
        category: "ShareCoordinator"
    )

    private override init() {
        super.init()
    }

    // MARK: - UICloudSharingControllerDelegate

    /// Called when the share is saved successfully.
    func cloudSharingController(
        _ csc: UICloudSharingController,
        failedToSaveShareWithError error: Error
    ) {
        logger.error("Share save FAILED: \(error.localizedDescription)")
    }

    /// Called when the share record is saved to CloudKit.
    func itemTitle(for csc: UICloudSharingController) -> String? {
        return "Family Meal Planner"
    }

    /// Called when the user stops sharing entirely.
    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        logger.info("User stopped sharing")
    }

    /// Called when the share is saved successfully.
    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        logger.info("Share saved successfully!")
    }
}
