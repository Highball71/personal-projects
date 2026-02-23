//
//  ProjectStatus.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation

/// Lifecycle status of a project.
/// Raw values are persisted in SwiftData -- don't change existing ones.
enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case active = "Active"
    case onHold = "On Hold"
    case completed = "Completed"
    case archived = "Archived"

    var id: String { rawValue }
}
