//
//  SupabaseRecipeDetailView.swift
//  FluffyList
//
//  "The Press" recipe detail. 230pt halftone photo, ink-2 kicker,
//  36pt Bold title, uppercase metadata, ruled ingredient rows with a
//  servings scaler, numbered METHOD steps with a fixed numeral
//  column, and a sticky bottom bar carrying the one filled button in
//  the app: "Add to the week".
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
    /// Short human message for a failed write (plan/favorite).
    @State private var actionErrorMessage: String?

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
                    // Full-bleed halftone photo, square corners, no scrim.
                    RecipeCardImage(recipe: recipe, height: 230)
                        .clipped()
                }

                // "Made this? Add your photo" prompt
                if recipe.homemadeImagePath == nil {
                    homemadePhotoPrompt
                }

                titleSection

                ingredientsSection
                    .padding(.top, 30)

                if !recipe.instructions.isEmpty {
                    methodSection
                        .padding(.top, 30)
                }

                if !recipe.notes.isEmpty {
                    notesSection
                        .padding(.top, 30)
                }

                if let source = sourceAttribution {
                    Text(source)
                        .font(.custom(FluffyFace.italic, size: 13))
                        .foregroundStyle(Color.fluffyTertiary)
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color.fluffyBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
        .tint(Color.fluffyAccent)
        // Sticky bottom bar on paper with a 1px ink top rule — the one
        // place a filled button appears in the app.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                FluffyRule(weight: 1, color: .fluffyPrimary)
                FluffyFilledButton(title: "Add to the week") {
                    showingDayPicker = true
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
            }
            .background(Color.fluffyBackground)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = actionErrorMessage {
                FluffyErrorBanner(
                    message: message,
                    onDismiss: { actionErrorMessage = nil }
                )
                .background(Color.fluffyBackground)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button {
                        Task {
                            if !(await recipeService.toggleFavorite(recipe)) {
                                actionErrorMessage = "Couldn't update favorites. Please try again."
                            }
                        }
                    } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(recipe.isFavorite ? Color.fluffyAccent : Color.fluffySecondary)
                    }
                    Button { showingEdit = true } label: {
                        Image(systemName: "pencil")
                            .foregroundStyle(Color.fluffyAccent)
                    }
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

    /// Ink-2 kicker, 36pt Bold title, one line of uppercase metadata.
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(kickerText)
                .font(.fluffyMastheadLabel)
                .fluffyTracking(0.16, at: 10)
                .foregroundStyle(Color.fluffyInk2)
                .padding(.bottom, 8)

            Text(recipe.name)
                .font(.fluffyTitle)
                .fluffyTracking(-0.03, at: 36)
                .lineSpacing(36 * 0.02)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.bottom, 10)

            FluffyMetadataLine(text: metadataText)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }

    private var kickerText: String {
        recipe.isFavorite ? "FAVOURITE" : recipe.category.uppercased()
    }

    private var metadataText: String {
        var parts = [recipe.category]
        if recipe.servings > 0 { parts.append("Serves \(recipe.servings)") }
        if totalMinutes > 0 { parts.append("\(totalMinutes) min") }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section head + serving scaler on the same line
            HStack {
                FluffySectionHead(title: "Ingredients")
                Spacer()
                servingsScaler
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 10)

            if isLoadingIngredients {
                Text("Fetching ingredients\u{2026}")
                    .font(.fluffyCallout)
                    .foregroundStyle(Color.fluffySecondary)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 8)
            } else if ingredients.isEmpty {
                Text("No ingredients listed.")
                    .font(.fluffyCallout)
                    .foregroundStyle(Color.fluffyTertiary)
                    .padding(.horizontal, 22)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(ingredients) { ingredient in
                        VStack(spacing: 0) {
                            FluffyRule().padding(.horizontal, 22)
                            ingredientRow(ingredient)
                        }
                    }
                    FluffyRule().padding(.horizontal, 22)
                }
            }
        }
    }

    /// Ruled ingredient row: name left at 17pt, scaled quantity right
    /// at 14pt in fluffySecondary, tabular numerals, never wrapping.
    private func ingredientRow(_ ingredient: RecipeIngredientRow) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(ingredient.name)
                .font(.custom(FluffyFace.regular, size: 17))
                .foregroundStyle(Color.fluffyPrimary)
                .multilineTextAlignment(.leading)
            Spacer()
            Text(quantityText(ingredient))
                .font(.custom(FluffyFace.regular, size: 14))
                .monospacedDigit()
                .fixedSize()
                .foregroundStyle(Color.fluffySecondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
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
                        scaledServings > 1 ? Color.fluffyAccent : Color.fluffyBorder
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
                        scaledServings < 24 ? Color.fluffyAccent : Color.fluffyBorder
                    )
            }
            .disabled(scaledServings >= 24)

            Image(systemName: "person.2")
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffySecondary)
        }
    }

    // MARK: - Method

    private var methodSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffySectionHead(title: "Method")
                .padding(.horizontal, 22)
                .padding(.bottom, 15)

            let steps = recipe.instructions
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            VStack(alignment: .leading, spacing: 18) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        // 28pt Bold ink-1 numeral in a fixed 34pt column.
                        Text("\(index + 1)")
                            .font(.custom(FluffyFace.bold, size: 28))
                            .fluffyTracking(-0.03, at: 28)
                            .foregroundStyle(Color.fluffyAccent)
                            .frame(width: 34, alignment: .leading)
                        Text(highlightIngredients(in: step))
                            .lineSpacing(17 * 0.5)
                    }
                    .padding(.horizontal, 22)
                }
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffySectionHead(title: "Notes")
                .padding(.horizontal, 22)
                .padding(.bottom, 10)
            Text(recipe.notes)
                .font(.fluffyCalloutLarge)
                .foregroundStyle(Color.fluffySecondary)
                .lineSpacing(17 * 0.4)
                .padding(.horizontal, 22)
        }
    }

    // MARK: - Ingredient Formatting

    /// The right-column quantity for an ingredient with the current
    /// scale factor applied — "1 1/2 lb", "to taste", "3".
    private func quantityText(_ ingredient: RecipeIngredientRow) -> String {
        let unit = IngredientUnit(rawValue: ingredient.unit)

        if unit == .toTaste { return "to taste" }

        let scaledQty = ingredient.quantity * scaleFactor
        let qty = FractionFormatter.formatAsFraction(scaledQty)

        // Spell out the enum case so Swift doesn't think we mean
        // Optional<IngredientUnit>.none — `unit == nil` already covers
        // that case; the second branch is for the explicit enum case.
        if unit == nil || unit == IngredientUnit.none { return qty }

        return "\(qty) \(unit!.displayName)"
    }

    // MARK: - Ingredient Highlighting

    /// Build an AttributedString with ingredient names set to Inter Semi Bold.
    private func highlightIngredients(in text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .custom(FluffyFace.regular, size: 17)
        result.foregroundColor = Color.fluffyPrimary

        for name in ingredientNames {
            guard name.count >= 3 else { continue }

            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result[searchStart...].range(
                      of: name,
                      options: .caseInsensitive
                  ) {
                result[range].font = .custom(FluffyFace.semibold, size: 17)
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
            .background(.ultraThinMaterial)
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
            .foregroundStyle(Color.fluffySecondary)
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
            .background(.ultraThinMaterial)
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

        guard result != nil else {
            actionErrorMessage = "Couldn't add that meal. Please try again."
            return
        }

        await mealPlanService.fetchPlans(
            weekStart: DateHelper.startOfWeek(containing: date)
        )

        let f = DateFormatter()
        f.dateFormat = "EEEE"
        withAnimation { toastMessage = "Added to \(f.string(from: date))" }
    }
}
