//
//  AddEditRecipeView.swift
//  Family Meal Planner
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Handles both adding a new recipe and editing an existing one.
/// When `recipeToEdit` is nil → add mode (form starts empty).
/// When `recipeToEdit` has a value → edit mode (form pre-populates).
struct AddEditRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Pass an existing recipe here to edit it. Leave nil to add a new one.
    var recipeToEdit: Recipe?

    // Form state — these are local copies. Nothing is saved to the
    // database until the user taps "Save".
    @State private var name = ""
    @State private var category: RecipeCategory = .dinner
    @State private var servings = 4
    @State private var prepTimeMinutes = 30
    @State private var instructions = ""
    @State private var ingredientRows: [IngredientFormData] = []
    @State private var sourceType: RecipeSource?
    @State private var sourceDetail = ""

    // Photo-to-recipe state
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isExtractingRecipe = false
    @State private var extractionError: String?
    @State private var showingExtractionError = false

    var isEditing: Bool { recipeToEdit != nil }

    /// Placeholder text that changes based on the selected source type
    private var sourcePlaceholder: String {
        switch sourceType {
        case .cookbook: "Book title, p. 42"
        case .website: "https://..."
        case .photo:   "Cookbook name"
        case .other:   "Where is this from?"
        case nil:      ""
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Recipe Info Section
                Section("Recipe Info") {
                    TextField("Recipe Name", text: $name)

                    // Photo-to-recipe: scan a cookbook page to auto-fill the form
                    Button {
                        showingPhotoOptions = true
                    } label: {
                        Label("Scan from Photo", systemImage: "camera.fill")
                    }
                    .disabled(isExtractingRecipe)

                    Picker("Category", selection: $category) {
                        ForEach(RecipeCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }

                    Stepper("Servings: \(servings)", value: $servings, in: 1...20)

                    Stepper(
                        "Prep Time: \(prepTimeMinutes) min",
                        value: $prepTimeMinutes,
                        in: 5...480,
                        step: 5
                    )
                }

                // MARK: - Ingredients Section
                Section("Ingredients") {
                    ForEach($ingredientRows) { $row in
                        IngredientRowView(data: $row)
                    }
                    .onDelete { indexSet in
                        ingredientRows.remove(atOffsets: indexSet)
                    }

                    Button("Add Ingredient") {
                        ingredientRows.append(IngredientFormData())
                    }
                }

                // MARK: - Instructions Section
                Section("Instructions") {
                    // TextEditor gives multi-line text input
                    // (TextField is single-line only)
                    TextEditor(text: $instructions)
                        .frame(minHeight: 150)
                }

                // MARK: - Source Section
                Section("Source") {
                    Picker("Source Type", selection: $sourceType) {
                        Text("None").tag(RecipeSource?.none)
                        ForEach(RecipeSource.allCases) { source in
                            Text(source.rawValue).tag(RecipeSource?.some(source))
                        }
                    }

                    // Only show the detail field when a source type is selected
                    if sourceType != nil {
                        TextField(sourcePlaceholder, text: $sourceDetail)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Recipe" : "New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        // Disable Save if the name is blank
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            // Choose between camera and photo library
            .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        showingPhotoOptions = false
                        showingCamera = true
                    }
                }
                Button("Choose from Library") {
                    showingPhotoOptions = false
                    showingPhotoLibrary = true
                }
                Button("Cancel", role: .cancel) {
                    showingPhotoOptions = false
                }
            }
            // Photo library picker
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            // Camera (UIImagePickerController wrapper)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    showingCamera = false
                    if let image {
                        Task { await extractRecipeFromImage(image) }
                    }
                }
                .ignoresSafeArea()
            }
            // When a photo is picked from the library, load it and extract
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await extractRecipeFromImage(image)
                    } else {
                        extractionError = "Could not load the selected photo."
                        showingExtractionError = true
                    }
                    selectedPhotoItem = nil
                }
            }
            // Loading overlay while Claude processes the image
            .overlay {
                if isExtractingRecipe {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Reading recipe from photo...")
                                .font(.headline)
                            Text("This may take a few seconds")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(32)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            // Error alert
            .alert("Recipe Extraction Failed", isPresented: $showingExtractionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(extractionError ?? "An unknown error occurred.")
            }
            .onAppear {
                // If editing, populate the form with the existing recipe's data
                if let recipe = recipeToEdit {
                    name = recipe.name
                    category = recipe.category
                    servings = recipe.servings
                    prepTimeMinutes = recipe.prepTimeMinutes
                    instructions = recipe.instructions
                    ingredientRows = recipe.ingredients.map { ingredient in
                        IngredientFormData(
                            name: ingredient.name,
                            quantity: ingredient.quantity,
                            unit: ingredient.unit
                        )
                    }
                    sourceType = recipe.sourceType
                    sourceDetail = recipe.sourceDetail ?? ""
                }
            }
        }
    }

    /// Send the image to Claude API and populate form fields with the result.
    @MainActor
    private func extractRecipeFromImage(_ image: UIImage) async {
        isExtractingRecipe = true
        extractionError = nil

        do {
            let extracted = try await ClaudeAPIService.extractRecipe(from: image)

            // Populate form fields with extracted data
            name = extracted.name
            category = extracted.recipeCategory
            servings = extracted.servings ?? 4
            prepTimeMinutes = extracted.prepTimeMinutes ?? 30
            instructions = extracted.instructions
            ingredientRows = extracted.ingredientFormRows

            // Auto-set source to "Photo from Cookbook"
            sourceType = .photo
        } catch {
            extractionError = error.localizedDescription
            showingExtractionError = true
        }

        isExtractingRecipe = false
    }

    private func saveRecipe() {
        // Filter out any blank ingredient rows
        let validIngredients = ingredientRows
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { Ingredient(name: $0.name, quantity: $0.quantity, unit: $0.unit) }

        if let recipe = recipeToEdit {
            // Update existing recipe
            recipe.name = name
            recipe.category = category
            recipe.servings = servings
            recipe.prepTimeMinutes = prepTimeMinutes
            recipe.instructions = instructions

            recipe.sourceType = sourceType
            recipe.sourceDetail = sourceDetail.isEmpty ? nil : sourceDetail

            // Replace all ingredients: delete old, add new
            for ingredient in recipe.ingredients {
                modelContext.delete(ingredient)
            }
            recipe.ingredients = validIngredients
        } else {
            // Create brand new recipe
            let recipe = Recipe(
                name: name,
                category: category,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                instructions: instructions,
                ingredients: validIngredients,
                sourceType: sourceType,
                sourceDetail: sourceDetail.isEmpty ? nil : sourceDetail
            )
            modelContext.insert(recipe)
        }

        dismiss()
    }
}

#Preview("Add Recipe") {
    AddEditRecipeView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
