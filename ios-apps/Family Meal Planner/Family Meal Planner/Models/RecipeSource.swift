//
//  RecipeSource.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// Where a recipe came from. Used to distinguish between manually entered
/// recipes, cookbook references, web links, and photos of cookbook pages
/// (for the upcoming photo-to-recipe feature).
enum RecipeSource: String, Codable, CaseIterable, Identifiable {
    case cookbook = "Cookbook"
    case website = "Website"
    case photo = "Photo from Cookbook"
    case other = "Other"

    var id: String { rawValue }
}
