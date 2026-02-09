//
//  SampleData.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import Foundation
import SwiftData

/// Inserts sample recipes on first launch so the app doesn't start empty.
/// Only runs once — if any recipes already exist, it does nothing.
enum SampleData {

    static func insertIfNeeded(into modelContext: ModelContext) {
        // Check if we already have recipes
        let descriptor = FetchDescriptor<Recipe>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        // MARK: - Sample Recipe 1: Spaghetti Bolognese

        let spaghetti = Recipe(
            name: "Spaghetti Bolognese",
            category: .dinner,
            servings: 4,
            prepTimeMinutes: 45,
            instructions: """
            1. Brown the ground beef in a large pan.
            2. Add diced onions and garlic, cook until soft.
            3. Add crushed tomatoes and Italian seasoning.
            4. Simmer for 20 minutes.
            5. Cook spaghetti according to package directions.
            6. Serve sauce over pasta.
            """,
            sourceType: .cookbook,
            sourceDetail: "The Joy of Cooking, p. 312"
        )
        spaghetti.ingredients = [
            Ingredient(name: "Spaghetti", quantity: 1, unit: .pound),
            Ingredient(name: "Ground beef", quantity: 1, unit: .pound),
            Ingredient(name: "Crushed tomatoes", quantity: 28, unit: .ounce),
            Ingredient(name: "Onion", quantity: 1, unit: .whole),
            Ingredient(name: "Garlic cloves", quantity: 3, unit: .piece),
        ]
        modelContext.insert(spaghetti)

        // MARK: - Sample Recipe 2: Scrambled Eggs

        let eggs = Recipe(
            name: "Scrambled Eggs",
            category: .breakfast,
            servings: 2,
            prepTimeMinutes: 10,
            instructions: """
            1. Whisk eggs with a splash of milk.
            2. Melt butter in a non-stick pan over medium-low heat.
            3. Pour in eggs, stir gently with a spatula.
            4. Remove from heat while still slightly wet.
            5. Season with salt and pepper.
            """
        )
        eggs.ingredients = [
            Ingredient(name: "Eggs", quantity: 4, unit: .piece),
            Ingredient(name: "Butter", quantity: 1, unit: .tablespoon),
            Ingredient(name: "Milk", quantity: 2, unit: .tablespoon),
        ]
        modelContext.insert(eggs)

        // MARK: - Sample Recipe 3: Chicken Caesar Salad

        let salad = Recipe(
            name: "Chicken Caesar Salad",
            category: .lunch,
            servings: 2,
            prepTimeMinutes: 20,
            instructions: """
            1. Season chicken breast with salt and pepper.
            2. Grill or pan-sear until cooked through (165°F internal).
            3. Slice chicken.
            4. Toss romaine lettuce with Caesar dressing.
            5. Top with sliced chicken, croutons, and parmesan.
            """,
            sourceType: .website,
            sourceDetail: "budgetbytes.com"
        )
        salad.ingredients = [
            Ingredient(name: "Chicken breast", quantity: 1, unit: .pound),
            Ingredient(name: "Romaine lettuce", quantity: 1, unit: .whole),
            Ingredient(name: "Caesar dressing", quantity: 3, unit: .tablespoon),
            Ingredient(name: "Parmesan cheese", quantity: 0.25, unit: .cup),
            Ingredient(name: "Croutons", quantity: 0.5, unit: .cup),
        ]
        modelContext.insert(salad)
    }
}
