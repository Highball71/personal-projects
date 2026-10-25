// Adaptive recipe detail with Recipe, Ingredients, Notes, and Photos sections.
// Original sources and household cooking history remain distinct.

import PhotosUI
import SwiftUI

struct SupabaseRecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingDishPhotoOptions = false
    @State private var showingDishCamera = false

    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var mealPlanService: MealPlanService
    @EnvironmentObject private var groceryService: GroceryService
    @EnvironmentObject private var householdService: HouseholdService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The row this screen was pushed with — a value snapshot, frozen
    /// at push time. Kept only as a fallback; rendering reads `recipe`.
    private let initialRecipe: RecipeRow

    init(recipe: RecipeRow, initialSection: DetailTab = .recipe) {
        self.initialRecipe = recipe
        _selectedSection = State(initialValue: initialSection)
    }

    /// The LIVE row, read from the service by id on every render, so a
    /// change that refreshes `recipeService.recipes` (a photo upload,
    /// an edit, a favorite toggle) appears on this screen immediately.
    /// Falls back to the pushed-in snapshot when the row isn't in the
    /// list (still loading, or deleted while this screen is open).
    private var recipe: RecipeRow {
        recipeService.recipes.first { $0.id == initialRecipe.id } ?? initialRecipe
    }

    /// All layout decisions for this screen, keyed off the size class
    /// alone — see RecipeDetailLayout. Compact values are the old
    /// phone constants.
    private var layout: RecipeDetailLayout {
        RecipeDetailLayout(isRegular: horizontalSizeClass == .regular)
    }

    enum DetailTab: String, CaseIterable { case recipe = "Recipe", ingredients = "Ingredients", notes = "Notes", photos = "Photos" }
    @State private var selectedSection: DetailTab = .recipe
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var familyHistory: [FamilyRecipePhoto] = []
    @State private var photoHistoryAvailable = false
    @State private var loadingPhotoHistory = true
    @State private var photoCaption = ""
    @State private var managingPhotos = false
    @State private var editingPhoto: FamilyRecipePhoto?
    @State private var editedCaption = ""
    @State private var savingPhotoChange = false
    @State private var showingGroceryPreview = false
    @State private var addingGroceries = false
    @State private var replacingSavedPhoto = false
    @State private var useLegacyPhotoSave = false
    @State private var ingredients: [RecipeIngredientRow] = []
    @State private var isLoadingIngredients = true
    @State private var showingEdit = false
    @State private var showingCookbookPhoto = false
    @State private var showingOriginalSource = false
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
            if layout.usesTwoColumns && !dynamicTypeSize.isAccessibilitySize && selectedSection == .recipe {
                regularContent
            } else {
                compactContent
            }
        }
        .background(Color.fluffyBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.fluffyBackground, for: .navigationBar)
        .tint(Color.fluffyAccent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if let message = actionErrorMessage {
                FluffyErrorBanner(
                    message: message,
                    onDismiss: { actionErrorMessage = nil }
                )
                .background(Color.fluffyBackground)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .confirmationDialog("Add a photo of your dish", isPresented: $showingDishPhotoOptions, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take a dish photo") { showingDishCamera = true }
            }
            Button("Choose a dish photo") { showingHomemadePhotoPicker = true }
        } message: {
            Text("For photos of food you cooked. Recipe pages stay under Original Recipe Source.")
        }
        .fullScreenCover(isPresented: $showingDishCamera) {
            CameraView { image in
                showingDishCamera = false
                if let image { Task { await uploadHomemadePhoto(image) } }
            }
        }
        .sheet(isPresented: $showingGroceryPreview) {
            NavigationStack {
                List {
                    Section {
                        ForEach(ingredients.sorted { $0.sortOrder < $1.sortOrder }) { ingredient in
                            VStack(alignment: .leading) {
                                Text(ingredient.name)
                                Text(IngredientDisplay.render(quantity: ingredient.quantity, unit: ingredient.unit, note: ingredient.note).combined)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: { Text("Saved recipe · \(recipe.servings) servings") }
                    footer: { Text("Adds the saved recipe quantities to your groceries. Existing items are combined. Your meal plan stays unchanged.") }
                }
                .navigationTitle("Add ingredients")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingGroceryPreview = false }.disabled(addingGroceries) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(addingGroceries ? "Adding…" : "Add") { Task { await addGroceriesOnly() } }
                            .disabled(addingGroceries || ingredients.isEmpty)
                    }
                }
                .interactiveDismissDisabled(addingGroceries)
            }
        }
        .sheet(item: $editingPhoto) { photo in
            NavigationStack {
                Form {
                    TextField("Cooking note", text: $editedCaption, axis: .vertical)
                        .onChange(of: editedCaption) { _, value in editedCaption = String(value.prefix(2000)) }
                }
                .navigationTitle("Photo note")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { editingPhoto = nil } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { Task { await updatePhoto(photo, caption: editedCaption, archived: photo.isArchived) } }
                            .disabled(savingPhotoChange)
                    }
                }
                .interactiveDismissDisabled(savingPhotoChange)
            }
        }
        .sheet(isPresented: $showingCookbookPhoto) {
            CookbookPhotoStepView(recipe: recipe, isAfterScan: false) { showingCookbookPhoto = false }
                .environmentObject(recipeService)
        }
        .sheet(isPresented: $showingOriginalSource) { RecipeSourceImageView(recipe: recipe) }
        .sheet(isPresented: $showingEdit) {
            SupabaseAddRecipeView(recipe: recipe, ingredients: ingredients)
                .fluffyRegularSheetSizing(layout.isRegular)
        }
        .sheet(isPresented: $showingDayPicker) {
            DayPickerSheet(
                recipe: recipe,
                members: householdService.members,
                ingredientNames: ingredients.map { $0.name.lowercased() },
                onPick: { date, memberID in
                    showingDayPicker = false
                    Task { await addToMealPlan(date: date, memberID: memberID) }
                },
                onCancel: { showingDayPicker = false }
            )
            .fluffyRegularSheetSizing(layout.isRegular)
        }
        .confirmationDialog("Replace the previously saved photo?", isPresented: $replacingSavedPhoto, titleVisibility: .visible) {
            Button("Replace Saved Photo", role: .destructive) {
                useLegacyPhotoSave = true
                showingHomemadePhotoPicker = true
            }
        } message: {
            Text("This replaces your previously saved family photo. Your original recipe source stays unchanged.")
        }
        .photosPicker(isPresented: $showingHomemadePhotoPicker, selection: $homemadePhotoItem, matching: .images)
        .onChange(of: homemadePhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await uploadHomemadePhoto(image)
                } else {
                    actionErrorMessage = "That photo could not be opened. Please choose it again."
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
            await loadPhotoHistory()
        }
        // Cookbook on a stand: the screen stays awake while a recipe
        // is showing — idle timer off on appear, restored on
        // disappear, and nowhere else in the app. (A sheet presented
        // over this screen does not fire onDisappear, so the hold
        // correctly survives the edit and day-picker sheets.)
        .onAppear { ScreenAwake.shared.begin() }
        .onDisappear { ScreenAwake.shared.end() }
    }

    // MARK: - Content Layouts

    /// The phone layout, unchanged: one column, everything stacked.
    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader
            if selectedSection != .photos { titleSection }
            sectionTabs
            switch selectedSection {
            case .recipe:
                recipeOverview
                recipeActions
                if !recipe.instructions.isEmpty { methodSection }
                cookbookSource
            case .ingredients:
                ingredientsSection
            case .notes:
                if recipe.notes.isEmpty {
                    Text("No notes yet. Add your cooking notes with Edit recipe.")
                        .font(.body).foregroundStyle(Color.fluffySecondary).padding(.horizontal, 22)
                } else { notesSection }
            case .photos:
                familyPhotos
                cookbookSource
            }
            Spacer(minLength: 24)
        }
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity)
    }

    private var sectionTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Button { selectedSection = tab } label: {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(selectedSection == tab ? .semibold : .regular))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 48)
                            .foregroundStyle(selectedSection == tab ? Color.fluffyAccent : Color.fluffySecondary)
                            .overlay(alignment: .bottom) {
                                if selectedSection == tab { Rectangle().fill(Color.fluffyAccent).frame(height: 2) }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedSection == tab ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var detailHeader: some View {
        ZStack(alignment: .top) {
            if selectedSection != .photos && recipe.hasDishPhoto {
                RecipeCardImage(recipe: recipe, height: horizontalSizeClass == .regular ? 320 : 250, role: .family)
            }
            HStack {
                RecipeIconButton(symbol: "chevron.left", label: "Back") { dismiss() }
                if selectedSection == .photos {
                    Text(recipe.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        .truncationMode(.tail).layoutPriority(-1)
                }
                Spacer()
                RecipeIconButton(symbol: recipe.isFavorite ? "heart.fill" : "heart", label: "Toggle favorite") {
                    Task {
                        if !(await recipeService.toggleFavorite(recipe)) { actionErrorMessage = "Couldn't update favorites. Please try again." }
                    }
                }
                RecipeIconButton(symbol: "pencil", label: "Edit recipe") { showingEdit = true }
            }
            .padding(.horizontal, 12).padding(.top, 8)
        }
    }

    private var recipeOverview: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { recipeFacts }
            VStack(alignment: .leading, spacing: 8) { recipeFacts }
        }
        .font(.subheadline)
        .padding(.horizontal, 16)
    }

    private var recipeActions: some View {
        VStack(spacing: 8) {
            Button { showingDayPicker = true } label: {
                Label("Add to Meal Plan", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.white)
                    .background(Color.fluffyButtonFill, in: RoundedRectangle(cornerRadius: 12))
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { secondaryRecipeActions }
                VStack(spacing: 8) { secondaryRecipeActions }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var secondaryRecipeActions: some View {
        Button { showingGroceryPreview = true } label: {
            Label("Add to Grocery List", systemImage: "cart")
                .font(.caption).fixedSize().frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoadingIngredients || ingredients.isEmpty || addingGroceries)
        Button { selectedSection = .ingredients } label: {
            Label("Scale Recipe", systemImage: "arrow.up.left.and.arrow.down.right")
                .font(.caption).fixedSize().frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var recipeFacts: some View {
        if totalMinutes > 0 {
            Label("\(totalMinutes) min", systemImage: "clock")
                .padding(12).background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 14))
        }
        if recipe.servings > 0 {
            Label("Serves \(recipe.servings)", systemImage: "fork.knife")
                .padding(12).background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var familyPhotos: some View {
        VStack(alignment: .leading, spacing: 16) {
            if loadingPhotoHistory {
                ProgressView("Loading family photos")
            } else if photoHistoryAvailable {
                TextField("A note about this meal (optional)", text: $photoCaption, prompt: Text("A note about this meal (optional)").foregroundStyle(Color.fluffySecondary), axis: .vertical)
                    .foregroundStyle(Color.fluffyPrimary)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: photoCaption) { _, value in photoCaption = String(value.prefix(2000)) }
                Button { useLegacyPhotoSave = false; showingDishPhotoOptions = true } label: {
                    Label("Made this recipe? Add a dish photo", systemImage: "camera")
                        .font(.body).frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .padding(16)
                        .background(Color.fluffyAccentPale, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            } else {
                Text("Photo history couldn’t be loaded. Your saved photo and original source are still available.")
                    .font(.body).foregroundStyle(Color.fluffySecondary)
                Button("Retry photo history") { Task { await loadPhotoHistory() } }
                    .frame(minHeight: 44)
                Button(recipe.homemadeImagePath == nil ? "Add your first photo" : "Replace previously saved photo") {
                    if recipe.homemadeImagePath == nil {
                        useLegacyPhotoSave = true
                        showingHomemadePhotoPicker = true
                    } else { replacingSavedPhoto = true }
                }
                .frame(minHeight: 44)
            }
            HStack {
                FluffySectionHead(title: "Our Family Photos")
                Spacer()
                Button(managingPhotos ? "Done" : "Manage") { managingPhotos.toggle() }.frame(minHeight: 44)
                    .disabled(!photoHistoryAvailable || savingPhotoChange)
            }
            if managingPhotos && recipe.familyCoverImagePath != nil {
                Button("Reset recipe cover") { Task { await setPhotoCover(nil) } }
                    .frame(minHeight: 44).disabled(savingPhotoChange)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 280 : 155))], alignment: .leading, spacing: 20) {
                ForEach(familyHistory.filter { managingPhotos || !$0.isArchived }) { photo in
                    VStack(alignment: .leading, spacing: 8) {
                        FamilyPhotoTile(photo: photo)
                        if recipe.familyCoverImagePath == photo.imagePath {
                            Label("Recipe cover", systemImage: "star.fill").font(.caption)
                        }
                        if photo.isArchived { Text("Archived").font(.caption).foregroundStyle(Color.fluffySecondary) }
                        if managingPhotos {
                            Menu("Photo options") {
                                Button("Edit note") { editedCaption = photo.caption; editingPhoto = photo }
                                if !photo.isArchived {
                                    Button("Use as recipe cover") { Task { await setPhotoCover(photo) } }
                                }
                                Button(photo.isArchived ? "Restore photo" : "Archive photo") {
                                    Task { await updatePhoto(photo, caption: photo.caption, archived: !photo.isArchived) }
                                }
                                .disabled(recipe.familyCoverImagePath == photo.imagePath)
                            }
                            .frame(minHeight: 44).disabled(savingPhotoChange)
                        }
                    }
                }
                if recipe.homemadeImagePath != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        RecipeCardImage(recipe: recipe, height: 200, role: .legacyFamily)
                        Text("Previously saved photo").font(.caption).foregroundStyle(Color.fluffySecondary)
                    }
                }
            }
            if familyHistory.isEmpty && recipe.homemadeImagePath == nil {
                Text("Your own cooking photos belong here. Original recipe images are kept separately.")
                    .font(.body).foregroundStyle(Color.fluffySecondary)
            }
        }
        .padding(.horizontal, 22)
    }

    private func setPhotoCover(_ photo: FamilyRecipePhoto?) async {
        savingPhotoChange = true
        defer { savingPhotoChange = false }
        do {
            try await FamilyPhotoService().setCover(photo, for: recipe)
            guard await recipeService.fetchRecipes() else {
                actionErrorMessage = "Cover saved, but the recipe could not refresh. Reopen it when connected."
                return
            }
        } catch { actionErrorMessage = "Couldn't change the cover. Please try again." }
    }

    private func updatePhoto(_ photo: FamilyRecipePhoto, caption: String, archived: Bool) async {
        savingPhotoChange = true
        defer { savingPhotoChange = false }
        do {
            try await FamilyPhotoService().update(photo, caption: caption, archived: archived)
            editingPhoto = nil
            await loadPhotoHistory()
        } catch {
            editingPhoto = nil
            actionErrorMessage = "Couldn't update the photo. Reset its cover first if you are archiving it, then try again."
        }
    }

    private func addGroceriesOnly() async {
        guard !addingGroceries else { return }
        guard SupabaseManager.shared.currentHouseholdID == recipe.householdID else {
            showingGroceryPreview = false
            actionErrorMessage = "Your household changed. Reopen the recipe before adding ingredients."
            return
        }
        addingGroceries = true
        defer { addingGroceries = false }
        let inserts = ingredients.sorted { $0.sortOrder < $1.sortOrder }.map {
            GroceryItemInsert(householdID: recipe.householdID, name: $0.name,
                              quantity: $0.quantity, unit: $0.unit, note: $0.note)
        }
        let saved = await groceryService.addItems(inserts)
        showingGroceryPreview = false
        if saved { toastMessage = "Ingredients added to groceries" }
        else { actionErrorMessage = "Couldn't finish adding ingredients. Check the grocery list before trying again." }
    }

    private func loadPhotoHistory() async {
        loadingPhotoHistory = true
        defer { loadingPhotoHistory = false }
        do {
            familyHistory = try await FamilyPhotoService().photos(for: recipe)
            photoHistoryAvailable = true
        } catch {
            photoHistoryAvailable = false
        }
    }

    @ViewBuilder
    private var cookbookSource: some View {
        cookbookPhotoSection
        if recipe.sourceImagePath != nil || sourceAttribution != nil {
            VStack(alignment: .leading, spacing: 12) {
                FluffySectionHead(title: "Original Recipe Source")
                if recipe.sourceImagePath != nil {
                    Button { showingOriginalSource = true } label: {
                        HStack(spacing: 12) {
                            RecipeCardImage(recipe: recipe, height: 100, role: .source)
                                .frame(width: 85)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Original recipe page").font(.subheadline.weight(.medium))
                                Text("Open the full page and zoom in")
                                    .font(.caption).foregroundStyle(Color.fluffySecondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                        }.frame(minHeight: 100)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View original recipe source, with zoom controls")
                }
                if let source = sourceAttribution {
                    Text(source).font(.body).foregroundStyle(Color.fluffySecondary)
                }
            }
            .padding(18)
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 22)
        }
    }

    private var cookbookPhotoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cookbook Photo").font(.headline)
            if recipe.cookbookImagePath != nil {
                RecipeCardImage(recipe: recipe, height: 180, role: .cookbook)
                Text(sourceAttribution ?? "From the recipe's cookbook")
                    .font(.caption).foregroundStyle(Color.fluffySecondary)
            }
            Button(recipe.cookbookImagePath == nil ? "Add the book’s dish photo" : "Replace cookbook photo") {
                showingCookbookPhoto = true
            }.font(.subheadline).frame(minHeight: 44).buttonStyle(.plain)
            Text("Book illustrations stay separate from your family’s cooking photos.")
                .font(.caption).foregroundStyle(Color.fluffySecondary)
        }.padding(16)
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 22)
    }

    /// The cookbook-on-a-stand layout (regular width): taller photo
    /// across the top, then the title over two ruled columns —
    /// ingredients fixed on the left, method (with notes and source)
    /// capped to a readable measure on the right, the whole block
    /// centered so an 11" landscape doesn't stretch the broadsheet
    /// edge to edge. Same sections as compact, rearranged.
    private var regularContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            detailHeader

            sectionTabs

            VStack(alignment: .leading, spacing: 0) {
                titleSection
                recipeOverview.padding(.top, 12)
                recipeActions.padding(.vertical, 12)

                HStack(alignment: .top, spacing: 0) {
                    ingredientsSection
                        .frame(width: layout.ingredientColumnWidth, alignment: .topLeading)

                    // The broadsheet column rule between ingredients
                    // and method — FluffyRule turned vertical.
                    Rectangle()
                        .fill(Color.fluffyDivider)
                        .frame(width: 1)

                    VStack(alignment: .leading, spacing: 0) {
                        if !recipe.instructions.isEmpty {
                            methodSection
                        }
                        if !recipe.notes.isEmpty {
                            notesSection
                                .padding(.top, 30)
                        }
                        cookbookSource
                    }
                    .frame(maxWidth: layout.stepColumnMaxWidth, alignment: .topLeading)

                    Spacer(minLength: 0)
                }
                .padding(.top, 30)
            }
            .frame(maxWidth: layout.contentMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)

            Spacer(minLength: 40)
        }
    }

    /// "From: seriouseats.com" — shared by both layouts.
    @ViewBuilder
    private var sourceAttributionText: some View {
        if let source = sourceAttribution {
            Text(source)
                .font(.custom(FluffyFace.italic, size: 13))
                .foregroundStyle(Color.fluffyTertiary)
                .padding(.horizontal, 22)
                .padding(.top, 20)
        }
    }

    // MARK: - Title

    /// Ink-2 kicker, 36pt Bold title, one line of uppercase metadata.
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(recipe.name)
                .font(.custom(FluffyFace.bold, size: horizontalSizeClass == .regular ? 34 : 28, relativeTo: .title2))
                .fluffyTracking(-0.03, at: layout.titleSize)
                .lineSpacing(layout.titleSize * 0.02)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.bottom, 10)

            FluffyMetadataLine(text: metadataText)
        }
        .padding(.horizontal, 22)
        .padding(.top, 0)
    }

    private var kickerText: String {
        recipe.isFavorite ? "FAVOURITE" : recipe.category.uppercased()
    }

    private var metadataText: String {
        var parts = [recipe.recipeCategory.rawValue.capitalized]
        if recipe.usesCookbookCover { parts.append("Cookbook photo") }
        if recipe.isFavorite { parts.append("Family favorite") }
        if totalMinutes > 0 { parts.append("\(totalMinutes) min") }
        return parts.joined(separator: " \u{00B7} ")
    }

    // MARK: - Ingredients

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section head + serving scaler on the same line
            VStack(alignment: .leading, spacing: 8) {
                FluffySectionHead(title: "Ingredients")
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
                .font(.custom(FluffyFace.regular, size: layout.bodySize))
                .foregroundStyle(Color.fluffyPrimary)
                .multilineTextAlignment(.leading)
            Spacer()
            Text(quantityText(ingredient))
                .font(.custom(FluffyFace.regular, size: layout.quantitySize))
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
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Decrease servings")
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
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Increase servings")
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
                        // Bold numeral (28pt/34pt column on the phone)
                        // in a fixed column, sized by the layout.
                        Text("\(index + 1)")
                            .font(.custom(FluffyFace.bold, size: layout.stepNumeralSize))
                            .fluffyTracking(-0.03, at: layout.stepNumeralSize)
                            .foregroundStyle(Color.fluffyAccent)
                            .frame(width: layout.stepNumeralColumnWidth, alignment: .leading)
                        Text(highlightIngredients(in: step.replacingOccurrences(of: #"^\d+[.)]\s*"#, with: "", options: .regularExpression)))
                            .lineSpacing(5)
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
            // .fluffyCalloutLarge is custom(italic, 17) — same face,
            // layout-sized.
            Text(recipe.notes)
                .font(.custom(FluffyFace.italic, size: layout.bodySize))
                .foregroundStyle(Color.fluffySecondary)
                .lineSpacing(layout.bodySize * 0.4)
                .padding(.horizontal, 22)
        }
    }

    // MARK: - Ingredient Formatting

    /// The right-column quantity for an ingredient with the current
    /// scale factor applied — "1 1/2 lb", "to taste", "3".
    private func quantityText(_ ingredient: RecipeIngredientRow) -> String {
        // One shared formatter with the grocery rows (IngredientDisplay)
        // — container sizes as "1 can (14.5 oz)", size descriptors
        // replacing "piece", note context after " · ".
        IngredientDisplay.render(
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            note: ingredient.note,
            scale: scaleFactor
        ).combined
    }

    // MARK: - Ingredient Highlighting

    /// Build an AttributedString with ingredient names set to Inter
    /// Semi Bold, at the layout's body size (17 on the phone).
    private func highlightIngredients(in text: String) -> AttributedString {
        var result = AttributedString(text)
        result.font = .custom(FluffyFace.regular, size: layout.bodySize)
        result.foregroundColor = Color.fluffyPrimary

        for name in ingredientNames {
            guard name.count >= 3 else { continue }

            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result[searchStart...].range(
                      of: name,
                      options: .caseInsensitive
                  ) {
                result[range].font = .custom(FluffyFace.semibold, size: layout.bodySize)
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

        // Both steps must succeed before "Photo added" can show. A
        // failure surfaces in the error banner — the old code returned
        // silently here, which is exactly the "picked a photo and
        // nothing happened" bug.
        if useLegacyPhotoSave {
            guard let path = await recipeService.uploadHomemadeImage(image, recipeID: recipe.id),
                  await recipeService.setHomemadeImagePath(path, recipeID: recipe.id) else {
                actionErrorMessage = "Couldn't save your photo. Please try again."
                return
            }
            await recipeService.fetchRecipes()
            toastMessage = "Photo saved"
            return
        }
        do {
            try await FamilyPhotoService().add(image, caption: photoCaption, to: recipe)
            photoCaption = ""
            await loadPhotoHistory()
            toastMessage = "Photo added"
        } catch {
            actionErrorMessage = "Couldn't save your photo. Your previous photos are unchanged. Please try again."
        }
    }

    // MARK: - Actions

    private func loadIngredients() async {
        ingredients = await recipeService.fetchIngredients(for: recipe.id)
        isLoadingIngredients = false
    }

    private func addToMealPlan(date: Date, memberID: UUID? = nil) async {
        let result = await mealPlanService.addMealWithGroceries(
            recipe: recipe,
            on: date,
            memberID: memberID,
            recipeService: recipeService,
            groceryService: groceryService
        )

        guard result != nil else {
            actionErrorMessage = mealPlanService.errorMessage ?? "Couldn't add that meal. Please try again."
            await mealPlanService.fetchPlans(weekStart: DateHelper.startOfWeek(containing: date), quiet: true)
            return
        }

        await mealPlanService.fetchPlans(
            weekStart: DateHelper.startOfWeek(containing: date)
        )

        let f = DateFormatter()
        f.dateFormat = "EEEE"
        let day = f.string(from: date)
        let memberName = memberID.flatMap { id in
            householdService.members.first { $0.id == id }?.displayName
        }
        withAnimation {
            toastMessage = memberName.map { "Added for \($0) \u{2014} \(day)" }
                ?? "Added to \(day)"
        }
    }
}

// MARK: - iPad sheet sizing

private extension View {
    /// Sheets reached from Recipe Detail on the REGULAR width present
    /// as a page-size sheet rather than the smaller default form
    /// sheet. iOS 18+ API; earlier iPadOS keeps the system form sheet
    /// (still a usable size, just smaller). Compact (the phone) is
    /// untouched — the modifier is a no-op there. Promote out of this
    /// file when phase 2 gives other screens iPad layouts.
    @ViewBuilder
    func fluffyRegularSheetSizing(_ isRegular: Bool) -> some View {
        if isRegular, #available(iOS 18.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
    }
}
