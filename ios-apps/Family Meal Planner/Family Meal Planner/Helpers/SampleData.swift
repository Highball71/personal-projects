//
//  SampleData.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import Foundation
import CoreData

/// Inserts sample recipes on first launch so the app doesn't start empty.
/// Only runs once — if any recipes already exist, it does nothing.
enum SampleData {

    static func insertIfNeeded(into context: NSManagedObjectContext) {
        // Check if we already have recipes
        let request = NSFetchRequest<CDRecipe>(entityName: "CDRecipe")
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        // MARK: - Sample Recipe 1: Spaghetti Bolognese

        let spaghetti = CDRecipe(context: context)
        spaghetti.id = UUID()
        spaghetti.name = "Spaghetti Bolognese"
        spaghetti.categoryRaw = RecipeCategory.dinner.rawValue
        spaghetti.servings = 4
        spaghetti.prepTimeMinutes = 45
        spaghetti.cookTimeMinutes = 0
        spaghetti.instructions = """
        1. Brown the ground beef in a large pan.
        2. Add diced onions and garlic, cook until soft.
        3. Add crushed tomatoes and Italian seasoning.
        4. Simmer for 20 minutes.
        5. Cook spaghetti according to package directions.
        6. Serve sauce over pasta.
        """
        spaghetti.dateCreated = Date()
        spaghetti.isFavorite = false
        spaghetti.sourceTypeRaw = RecipeSource.cookbook.rawValue
        spaghetti.sourceDetail = "The Joy of Cooking, p. 312"

        let ingredients1 = [
            ("Spaghetti", 1.0, IngredientUnit.pound),
            ("Ground beef", 1.0, IngredientUnit.pound),
            ("Crushed tomatoes", 28.0, IngredientUnit.ounce),
            ("Onion", 1.0, IngredientUnit.whole),
            ("Garlic cloves", 3.0, IngredientUnit.piece),
        ]
        for (name, qty, unit) in ingredients1 {
            let ingredient = CDIngredient(context: context)
            ingredient.id = UUID()
            ingredient.name = name
            ingredient.quantity = qty
            ingredient.unitRaw = unit.rawValue
            ingredient.recipe = spaghetti
        }

        // MARK: - Sample Recipe 2: Scrambled Eggs

        let eggs = CDRecipe(context: context)
        eggs.id = UUID()
        eggs.name = "Scrambled Eggs"
        eggs.categoryRaw = RecipeCategory.breakfast.rawValue
        eggs.servings = 2
        eggs.prepTimeMinutes = 10
        eggs.cookTimeMinutes = 0
        eggs.instructions = """
        1. Whisk eggs with a splash of milk.
        2. Melt butter in a non-stick pan over medium-low heat.
        3. Pour in eggs, stir gently with a spatula.
        4. Remove from heat while still slightly wet.
        5. Season with salt and pepper.
        """
        eggs.dateCreated = Date()
        eggs.isFavorite = false

        let ingredients2 = [
            ("Eggs", 4.0, IngredientUnit.piece),
            ("Butter", 1.0, IngredientUnit.tablespoon),
            ("Milk", 2.0, IngredientUnit.tablespoon),
        ]
        for (name, qty, unit) in ingredients2 {
            let ingredient = CDIngredient(context: context)
            ingredient.id = UUID()
            ingredient.name = name
            ingredient.quantity = qty
            ingredient.unitRaw = unit.rawValue
            ingredient.recipe = eggs
        }

        // MARK: - Sample Recipe 3: Chicken Caesar Salad

        let salad = CDRecipe(context: context)
        salad.id = UUID()
        salad.name = "Chicken Caesar Salad"
        salad.categoryRaw = RecipeCategory.lunch.rawValue
        salad.servings = 2
        salad.prepTimeMinutes = 20
        salad.cookTimeMinutes = 0
        salad.instructions = """
        1. Season chicken breast with salt and pepper.
        2. Grill or pan-sear until cooked through (165°F internal).
        3. Slice chicken.
        4. Toss romaine lettuce with Caesar dressing.
        5. Top with sliced chicken, croutons, and parmesan.
        """
        salad.dateCreated = Date()
        salad.isFavorite = false
        salad.sourceTypeRaw = RecipeSource.website.rawValue
        salad.sourceDetail = "budgetbytes.com"

        let ingredients3 = [
            ("Chicken breast", 1.0, IngredientUnit.pound),
            ("Romaine lettuce", 1.0, IngredientUnit.whole),
            ("Caesar dressing", 3.0, IngredientUnit.tablespoon),
            ("Parmesan cheese", 0.25, IngredientUnit.cup),
            ("Croutons", 0.5, IngredientUnit.cup),
        ]
        for (name, qty, unit) in ingredients3 {
            let ingredient = CDIngredient(context: context)
            ingredient.id = UUID()
            ingredient.name = name
            ingredient.quantity = qty
            ingredient.unitRaw = unit.rawValue
            ingredient.recipe = salad
        }

        try? context.save()
    }
}
