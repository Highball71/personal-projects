//
//  RelationshipType.swift
//  Tralfaz
//
//  Created by David Albert on 2/22/26.
//

import Foundation

/// The nature of your relationship with a contact.
/// Raw values are persisted in SwiftData -- don't change existing ones.
enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case friend = "Friend"
    case family = "Family"
    case colleague = "Colleague"
    case client = "Client"
    case acquaintance = "Acquaintance"
    case other = "Other"

    var id: String { rawValue }
}
