//
//  Logging.swift
//  FluffyList
//
//  Standardized os.Logger instances by category.
//  Use these instead of print() for structured, filterable logging.

import Foundation
import os

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.highball71.fluffylist"

    static let importPipeline = Logger(subsystem: subsystem, category: "import")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let cloudkit = Logger(subsystem: subsystem, category: "cloudkit")
    static let search = Logger(subsystem: subsystem, category: "search")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
}
