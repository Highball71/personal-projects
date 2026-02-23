//
//  TaskPriority.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation

/// Priority levels for tasks.
/// Raw values are persisted in SwiftData -- don't change existing ones.
enum TaskPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}
