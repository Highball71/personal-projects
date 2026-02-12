//
//  RecipeSource.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// Where a recipe came from. Used to distinguish between manually entered
/// recipes, cookbook references, web links, photos of cookbook pages,
/// and URLs imported via the "Import from URL" feature.
enum RecipeSource: String, Codable, CaseIterable, Identifiable {
    case cookbook = "Cookbook"
    case website = "Website"
    case photo = "Photo from Cookbook"
    case url = "Imported from URL"
    case other = "Other"

    var id: String { rawValue }
}
