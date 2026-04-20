//
//  SupabaseRecipeDetailView.swift
//  FluffyList
//
//  Read-only recipe detail screen for the Supabase path.
//  Figma spec: Playfair Display bold title, amber section headers,
//  bullet-dot ingredients with a servings scaler, bold ingredient
//  names in prep steps, notes section, and an amber "Add to This
//  Week" button.
//

import PhotosUI
import SwiftUI

struct SupabaseRecipeDetailView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var groceryService: GroceryService

    let recipe: RecipeRow

    @State private var ingredients: [RecipeIngredientRow] = []
    @State private var isLoadingIngredients = true
    @State private var showingEdit = false
    @State private var showingDayPicker = false
    @State private var toastMessage: String?
    @State private var showingHomemadePhotoPicker = false
    @State private var homemadePhotoItem: PhotosPickerItem?
    @State private var isUploadingHomemade = false

    /// User-adjustable serving count — defaults to the recipe's saved value.
    @State private var scaledServings: Int = 0

    private var totalMinutes: Int {
        recipe.prepTimeMinutes + recipe.cookTimeMinutes
    }

    /// How much to multiply each ingredient quantity.
    private var scaleFactor: Double {
        guard recipe.servings > 0 else { return 1 }
        return Double(scaledServings) / Double(recipe.servings)
    }

    /// Ingredient names sorted longest-first so highlighting
    /// doesn't get tripped up by partial substring matches.
    private var ingredientNames: [String] {
        ingredients
            .map(\.name)
            .sorted { $0.count > $1.count }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if recipe.sourceImagePath != nil || recipe.homemadeImagePath != nil {
                    RecipeCardImage(recipe: recipe, height: 220)
                        .clipped()
                }

                // "Made this? Add your photo" prompt
                if recipe.homemadeImagePath == nil {
                    homemadePhotoPrompt
                }

                titleSection
                metadataRow
                sectionDivider

                ingredientsSection
                    .padding(.top, 24)

                if !recipe.instructions.isEmpty {
                    sectionDivider.padding(.top, 24)
                    preparationSection
                        .padding(.top, 24)
                }

                if !recipe.notes.isEmpty {
                    sectionDivider.padding(.top, 24)
                    notesSection
                        .padding(.top, 24)
                }

                if let source = sourceAttribution {
                    Text(source)
                        .font(.fluffyCaption)
                        .foregroundStyle(Color.fluffyTertiary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                }

                // Primary CTA
                FluffyPrimaryButton(
                    "Add to This Week",
                    icon: "calendar.badge.plus",
                    section: .recipes
                ) {
                    showingDayPicker = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 32)
                .padding(.bottom, 40)
            }
        }
        .background(Color.fluffyBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        Task { await recipeService.toggleFavorite(recipe) }
                    } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(recipe.isFavorite ? Color.fluffyAmber : Color.fluffySecondary)
                    }
                    Button("Edit") { showingEdit = true }
                        .foregroundStyle(Color.fluffyAmber)
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            SupabaseAddRecipeView(recipe: recipe, ingredients: ingredients)
        }
        .sheet(isPresented: $showingDayPicker) {
            DayPickerSheet(
                recipe: recipe,
                onPick: { date in
                    showingDayPicker = false
                    Task { await addToMealPlan(date: date) }
                },
                onCancel: { showingDayPicker = false }
            )
        }
        .photosPicker(isPresented: $showingHomemadePhotoPicker, selection: $homemadePhotoItem, matching: .images)
        .onChange(of: homemadePhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadHomemadePhoto(image)
                }
                homemadePhotoItem = nil
            }
        }
        .overlay { toastOverlay }
        .overlay { uploadingOverlay }
        .task {
            // Initialize the stepper to the recipe's default servings
            if scaledServings == 0 { scaledServings = max(recipe.servings, 1) }
            await loadIngredients()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        Text(recipe.name)
            .font(.fluffyDisplay)
            .foregroundStyle(Color.fluffyPrimary)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
    }

    // MARK: - Metadata Chips

    private var metadataRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FluffyMetadataChip(
                    icon: "tag",
                    value: recipe.category.capitalized
                )
                if recipe.servings > 0 {
                    FluffyMetadataChip(
                        icon: "person.2",
                        value: "Serves \(recipe.servings)"
                    )
                }
                if totalMinutes > 0 {
                    FluffyMetadataChip(
                        icon: "clock",
                        value: "\(totalMinutes) min"
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header + serving scaler on the same line
            HStack {
                FluffySectionHeader(title: "Ingredients")
                Spacer()
                servingsScaler
            }
            .padding(.horizontal, 20)

            if isLoadingIngredients {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if ingredients.isEmpty {
                Text("No ingredients listed")
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyTertiary)
                    .padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(ingredients) { ingredient in
                        FluffyBulletRow(text: formatIngredient(ingredient))
                            .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    /// Compact stepper that adjusts the scaled servings count.
    private var servingsScaler: some View {
        HStack(spacing: 8) {
            Button {
                if scaledServings > 1 {
                    withAnimation { scaledServings -= 1 }
                }
            } label: {
                Image(systemName: "minus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        scaledServings > 1 ? Color.fluffyAmber : Color.fluffyDivider
                    )
            }
            .disabled(scaledServings <= 1)

            Text("\(scaledServings)")
                .font(.fluffyHeadline)
                .foregroundStyle(Color.fluffyPrimary)
                .frame(minWidth: 20)
                .contentTransition(.numericText())

            Button {
                if scaledServings < 24 {
                    withAnimation { scaledServings += 1 }
                }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        scaledServings < 24 ? Color.fluffyAmber : Color.fluffyDivider
                    )
            }
            .disabled(scaledServings >= 24)

            Image(systemName: "person.2")
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffySecondary)
        }
    }

    // MARK: - Preparation

    private var preparationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Preparation")
                .padding(.horizontal, 20)

            let steps = recipe.instructions
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                    Text(highlightIngredients(in: step))
                        .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Notes")
                .padding(.horizontal, 20)
            Text(recipe.notes)
                .font(.custom("PlayfairDisplay-Bold", size: 16))
                .italic()
                .foregroundStyle(Color.fluffySecondary)
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(Color.fluffyDivider)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    // MARK: - Ingredient Formatting

    /// Format a single ingredient with the current scale factor applied.
    /// "to taste" → "Salt, to taste"
    /// "—" (none) → "3 eggs"
    /// Normal → "1 1/2 cups all-purpose flour"
    private func formatIngredient(_ ingredient: RecipeIngredientRow) -> String {
        let unit = IngredientUnit(rawValue: ingredient.unit)

        if unit == .toTaste {
            return "\(ingredient.name), to taste"
        }

        let scaledQty = ingredient.quantity * scaleFactor
        let qty = FractionFormatter.formatAsFraction(scaledQty)

        // Spell out the enum case so Swift doesn't think we mean
        // Optional<IngredientUnit>.none — `unit == nil` already covers
        // that case; the second branch is for the explicit enum case.
        if unit == nil || unit == IngredientUnit.none {
            return "\(qty) \(ingredient.name)"
        }

        return "\(qty) \(unit!.displayName) \(ingredient.name)"
    }

    // MARK: - Ingredient Highlighting

    /// Build an AttributedString with ingredient names set to Inter Semi Bold.
    private func highlightIngredients(in text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .custom("Inter-Regular", size: 16)
        result.foregroundColor = Color.fluffyPrimary

        for name in ingredientNames {
            guard name.count >= 3 else { continue }

            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result[searchStart...].range(
                      of: name,
                      options: .caseInsensitive
                  ) {
                result[range].font = .custom("Inter-SemiBold", size: 16)
                searchStart = range.upperBound
            }
        }

        return result
    }

    // MARK: - Source Attribution

    private var sourceAttribution: String? {
        guard let sourceType = recipe.sourceType,
              let detail = recipe.sourceDetail,
              !detail.isEmpty else {
            return nil
        }

        if sourceType == "url",
           let url = URL(string: detail),
           let host = url.host {
            let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            return "From: \(domain)"
        }

        return "From: \(detail)"
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let message = toastMessage {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fluffySuccess)
                Text(message)
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { toastMessage = nil }
                }
            }
        }
    }

    // MARK: - Homemade Photo

    private var homemadePhotoPrompt: some View {
        Button {
            showingHomemadePhotoPicker = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera")
                    .font(.fluffyCallout)
                Text("Made this? Add your photo")
                    .font(.fluffyCallout)
            }
            .foregroundStyle(Color.fluffyTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var uploadingOverlay: some View {
        if isUploadingHomemade {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.3)
                Text("Saving photo...")
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func uploadHomemadePhoto(_ image: UIImage) async {
        isUploadingHomemade = true
        defer { isUploadingHomemade = false }

        guard let path = await recipeService.uploadHomemadeImage(image, recipeID: recipe.id) else {
            return
        }

        await recipeService.setHomemadeImagePath(path, recipeID: recipe.id)
        await recipeService.fetchRecipes()
        withAnimation { toastMessage = "Photo added" }
    }

    // MARK: - Actions

    private func loadIngredients() async {
        ingredients = await recipeService.fetchIngredients(for: recipe.id)
        isLoadingIngredients = false
    }

    private func addToMealPlan(date: Date) async {
        let result = await mealPlanService.addMealWithGroceries(
            recipe: recipe,
            on: date,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else { return }

        await mealPlanService.fetchPlans(
            weekStart: DateHelper.startOfWeek(containing: date)
        )

        let f = DateFormatter()
        f.dateFormat = "EEEE"
        withAnimation { toastMessage = "Added to \(f.string(from: date))" }
    }
}
