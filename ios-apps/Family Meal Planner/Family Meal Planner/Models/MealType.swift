//
//  MealType.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation

/// The three meal slots available each day.
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"

    var id: String { rawValue }
}
