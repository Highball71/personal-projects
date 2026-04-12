//
//  SupabaseAddRecipeView.swift
//  FluffyList
//
//  Full recipe creation form backed by Supabase.
//  Structured ingredients with name/quantity/unit,
//  instructions, category, servings, prep/cook times, and source.
//
//  Reuses existing shared components:
//    - IngredientRowView / IngredientFormData (ingredient row UI)
//    - RecipeCategory, RecipeSource, IngredientUnit (shared enums)
//

import os
import SwiftUI

struct SupabaseAddRecipeView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel = SupabaseRecipeFormViewModel()

    var body: some View {
        NavigationStack {
            Form {
                recipeInfoSection
                ingredientsSection
                instructionsSection
                sourceSection

                if let error = viewModel.saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveRecipe() }
                    }
                    .disabled(!viewModel.validate() || viewModel.isSaving)
                }
            }
        }
    }

    // MARK: - Recipe Info

    private var recipeInfoSection: some View {
        Section("Recipe Info") {
            TextField("Recipe Name", text: $viewModel.name)

            Picker("Category", selection: $viewModel.category) {
                ForEach(RecipeCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }

            Stepper("Servings: \(viewModel.servings)", value: $viewModel.servings, in: 1...20)

            Stepper(
                "Prep Time: \(viewModel.prepTimeMinutes) min",
                value: $viewModel.prepTimeMinutes,
                in: 0...480,
                step: 5
            )

            Stepper(
                "Cook Time: \(viewModel.cookTimeMinutes) min",
                value: $viewModel.cookTimeMinutes,
                in: 0...480,
                step: 5
            )
        }
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        Section("Ingredients") {
            ForEach($viewModel.ingredientRows) { $row in
                IngredientRowView(data: $row)
            }
            .onDelete { indexSet in
                viewModel.ingredientRows.remove(atOffsets: indexSet)
            }

            Button("Add Ingredient") {
                viewModel.ingredientRows.append(IngredientFormData())
            }
        }
    }

    // MARK: - Instructions

    private var instructionsSection: some View {
        Section("Instructions") {
            TextEditor(text: $viewModel.instructions)
                .frame(minHeight: 150)
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        Section("Source") {
            Picker("Source Type", selection: $viewModel.sourceType) {
                Text("None").tag(RecipeSource?.none)
                ForEach(RecipeSource.allCases) { source in
                    Text(source.rawValue).tag(RecipeSource?.some(source))
                }
            }

            if viewModel.sourceType != nil {
                TextField(viewModel.sourcePlaceholder, text: $viewModel.sourceDetail)
            }
        }
    }

    // MARK: - Save

    private func saveRecipe() async {
        let success = await viewModel.save(
            recipeService: recipeService
        )

        if success {
            dismiss()
        }
    }
}
