//
//  RecipeFormSections.swift
//  Family Meal Planner
//
//  Extracted form sections for AddEditRecipeView.
//  Each section takes the ViewModel (and coordinator where needed) as a parameter.

import SwiftUI

// MARK: - Recipe Basics

struct RecipeBasicsSection: View {
    @Bindable var viewModel: RecipeFormViewModel
    var coordinator: RecipeImportCoordinator

    var body: some View {
        Section("Recipe Info") {
            TextField("Recipe Name", text: $viewModel.name)

            Button {
                coordinator.showingPhotoOptions = true
            } label: {
                Label("Scan from Photo", systemImage: "camera.fill")
            }
            .disabled(coordinator.isExtractingRecipe)

            Button {
                coordinator.importURLText = ""
                coordinator.showingURLInput = true
            } label: {
                Label("Import from URL", systemImage: "link")
            }
            .disabled(coordinator.isExtractingRecipe)

            Button {
                coordinator.showingRecipeSearch = true
            } label: {
                Label("Search Online", systemImage: "magnifyingglass")
            }
            .disabled(coordinator.isExtractingRecipe)

            Picker("Category", selection: $viewModel.category) {
                ForEach(RecipeCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }

            Stepper("Servings: \(viewModel.servings)", value: $viewModel.servings, in: 1...20)

            Stepper(
                "Prep Time: \(viewModel.prepTimeMinutes) min",
                value: $viewModel.prepTimeMinutes,
                in: 5...480,
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
}

// MARK: - Ingredients

struct RecipeIngredientsSection: View {
    @Bindable var viewModel: RecipeFormViewModel

    var body: some View {
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
}

// MARK: - Instructions

struct RecipeInstructionsSection: View {
    @Bindable var viewModel: RecipeFormViewModel

    var body: some View {
        Section("Instructions") {
            TextEditor(text: $viewModel.instructions)
                .frame(minHeight: 150)
        }
    }
}

// MARK: - Source

struct RecipeSourceSection: View {
    @Bindable var viewModel: RecipeFormViewModel

    var body: some View {
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
}
