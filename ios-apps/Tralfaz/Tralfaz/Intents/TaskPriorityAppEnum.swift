//
//  TaskPriorityAppEnum.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import AppIntents

/// Makes TaskPriority understandable by Siri and the Shortcuts app.
enum TaskPriorityAppEnum: String, AppEnum {
    case low
    case medium
    case high

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Priority")

    static var caseDisplayRepresentations: [TaskPriorityAppEnum: DisplayRepresentation] = [
        .low: "Low",
        .medium: "Medium",
        .high: "High"
    ]

    /// Convert to the SwiftData-persisted TaskPriority enum.
    var toTaskPriority: TaskPriority {
        switch self {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
}
