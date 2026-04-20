//
//  SupabaseAddRecipeView.swift
//  FluffyList
//
//  Full recipe creation and editing form backed by Supabase.
//  Heirloom design — ScrollView + card sections, not system Form.
//  Supports manual entry and photo import (camera → Claude Vision API).
//

import os
import PhotosUI
import SwiftUI

struct SupabaseAddRecipeView: View {
    @EnvironmentObject private var recipeService: RecipeService
    @EnvironmentObject private var groceryService: GroceryService
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SupabaseRecipeFormViewModel
    @State private var showingDeleteConfirmation = false
    @State private var showingGroceryAddedConfirmation = false
    @State private var isAddingToGrocery = false

    // Photo import state
    @State private var showingPhotoOptions = false
    @State private var showingCamera = false
    /// Single-image picker used for setting the recipe's card photo
    /// (the displayed source image on the recipe row).
    @State private var showingPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    /// Multi-image picker used for importing a recipe from photos of
    /// cookbook pages. Allows up to 5 images; all are sent together to
    /// the OCR pipeline and combined into a single recipe.
    @State private var showingRecipePhotoLibrary = false
    @State private var selectedRecipePhotoItems: [PhotosPickerItem] = []
    @State private var isExtracting = false
    @State private var extractingPageCount: Int = 0
    @State private var extractionError: String?
    @State private var showingExtractionError = false
    @State private var showingCameraPermissionDenied = false
    @State private var showingExtractionSuccess = false
    /// Set when an extraction completed but its recipe name collides
    /// with an existing recipe. Drives the three-button dialog so the
    /// user picks Update / New Copy / Cancel — preventing silent loss
    /// of the just-extracted ingredients and instructions.
    @State private var extractionDuplicateExisting: RecipeRow?
    @State private var showingExtractionDuplicate = false
    /// Phase 1 URL import state. The sheet stays presented while the
    /// import is running so the user gets inline progress; on success
    /// the sheet dismisses and the form is populated for review.
    @State private var showingURLImport = false
    @State private var importURL = ""
    @State private var isImportingFromURL = false
    /// When true, the shared photo library picker routes to the recipe
    /// card image flow instead of the scan extraction flow.

    /// Add mode — blank form.
    init() {
        self._viewModel = State(initialValue: SupabaseRecipeFormViewModel())
    }

    /// Edit mode — pre-populated from existing recipe.
    init(recipe: RecipeRow, ingredients: [RecipeIngredientRow]) {
        self._viewModel = State(initialValue: SupabaseRecipeFormViewModel(
            recipe: recipe,
            ingredients: ingredients
        ))
    }

    // MARK: - Body
    //
    // The body is intentionally a tiny expression that delegates to
    // computed-property subviews and helper methods that wrap modifier
    // chains. The original single expression (form + ~14 chained
    // modifiers + 3 overlays) blew past the Swift type-checker's
    // budget and produced "unable to type-check this expression in
    // reasonable time." Splitting at modifier-group boundaries gives
    // each chain its own inference scope and resolves it.

    var body: some View {
        NavigationStack {
            withOverlays(
                withExtractionSurfaces(
                    withPhotoSurfaces(
                        formContent
                    )
                )
            )
        }
    }

    // MARK: - Body: form content

    /// The scrollable form (all field cards + save button + edit
    /// actions) with its always-on chrome (background, nav title,
    /// toolbar, delete-confirmation alert). Everything below this in
    /// the modifier chain is dialogs / pickers / overlays grouped
    /// into helpers below.
    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                photoBlock
                scanBlock
                urlImportBlock
                nameBlock
                categoryChips
                detailsCard
                ingredientsCard
                instructionsCard
                notesCard
                sourceCard

                saveErrorBanner
                saveButton

                if viewModel.isEditing {
                    editActions
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(Color.fluffyBackground)
        .navigationTitle(viewModel.isEditing ? "Edit Recipe" : "New Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.fluffySecondary)
            }
        }
        .alert("Delete this recipe?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteRecipe() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This can't be undone.")
        }
    }

    @ViewBuilder
    private var saveErrorBanner: some View {
        if let error = viewModel.saveError {
            Text(error)
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffyError)
                .padding(.horizontal, 20)
        }
    }

    private var saveButton: some View {
        FluffyPrimaryButton(
            "Save Recipe",
            icon: "checkmark",
            section: .recipes
        ) {
            Task { await saveRecipe() }
        }
        .disabled(!viewModel.validate() || viewModel.isSaving)
        .opacity(viewModel.validate() && !viewModel.isSaving ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Body: modifier groups

    /// Camera, photo library, and image-picking modifiers. Grouped so
    /// the type-checker resolves their generic chain in isolation.
    private func withPhotoSurfaces<V: View>(_ content: V) -> some View {
        content
            .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Scan Pages") {
                        showingPhotoOptions = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showingCamera = true
                        }
                    }
                }
                Button("Choose from Library") {
                    showingPhotoOptions = false
                    showingRecipePhotoLibrary = true
                }
                Button("Cancel", role: .cancel) {
                    showingPhotoOptions = false
                }
            }
            .photosPicker(isPresented: $showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            .photosPicker(
                isPresented: $showingRecipePhotoLibrary,
                selection: $selectedRecipePhotoItems,
                maxSelectionCount: 5,
                matching: .images
            )
            .fullScreenCover(isPresented: $showingCamera) {
                RecipeScanView(
                    onDone: { images in
                        showingCamera = false
                        Logger.supabase.info("Photo import: RecipeScanView onDone with \(images.count) image(s)")
                        Task { await extractRecipe(from: images) }
                    },
                    onCancel: {
                        showingCamera = false
                        Logger.supabase.info("Photo import: RecipeScanView cancelled")
                    }
                )
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                // Card-photo flow only — single image, no extraction.
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        viewModel.sourceImage = image
                        viewModel.sourceImageRemoved = false
                    }
                    selectedPhotoItem = nil
                }
            }
            .sheet(isPresented: $showingURLImport) {
                URLImportSheet(
                    url: $importURL,
                    isImporting: isImportingFromURL,
                    onImport: {
                        Task { await importFromURL() }
                    },
                    onCancel: {
                        guard !isImportingFromURL else { return }
                        showingURLImport = false
                        importURL = ""
                    }
                )
                .presentationDetents([.height(240)])
                .interactiveDismissDisabled(isImportingFromURL)
            }
            .onChange(of: selectedRecipePhotoItems) { _, newItems in
                // Multi-image recipe-import flow — load all selected
                // photos in pick order, then send the array to the
                // existing extractRecipe pipeline. Order matters because
                // the multi-page OCR prompt treats them as consecutive
                // pages of one recipe.
                guard !newItems.isEmpty else { return }
                let items = newItems
                Logger.supabase.info("Photo import: PhotosPicker returned \(items.count) item(s)")
                Task {
                    var images: [UIImage] = []
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        } else {
                            // Fail closed — "no data loss between images"
                            // means we'd rather show an error than
                            // silently OCR a partial set.
                            Logger.supabase.error("Photo import: failed to load one of the picked photos")
                            extractionError = "Couldn't load one of the selected photos. Please try again."
                            showingExtractionError = true
                            selectedRecipePhotoItems = []
                            return
                        }
                    }
                    selectedRecipePhotoItems = []
                    await extractRecipe(from: images)
                }
            }
    }

    /// Extraction error alert, the duplicate-recipe choice dialog,
    /// and the camera-permission alert. Grouped so the type-checker
    /// resolves their generic chain in isolation.
    private func withExtractionSurfaces<V: View>(_ content: V) -> some View {
        content
            .alert("Couldn't Read Recipe", isPresented: $showingExtractionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(extractionError ?? "Something went wrong. Please try again.")
            }
            .confirmationDialog(
                "Recipe Already Exists",
                isPresented: $showingExtractionDuplicate,
                titleVisibility: .visible,
                presenting: extractionDuplicateExisting
            ) { existing in
                Button("Update Existing Recipe") {
                    Task { await applyExtractionAsUpdate(of: existing) }
                }
                Button("Create New Copy") {
                    Task { await applyExtractionAsNewCopy() }
                }
                Button("Cancel", role: .cancel) {
                    extractionDuplicateExisting = nil
                }
            } message: { existing in
                Text("\"\(existing.name)\" is already in your recipes. Update it with the new scan, save the new scan as a separate copy, or cancel to keep the existing recipe and discard the scan.")
            }
            .alert("Camera Access Required", isPresented: $showingCameraPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("FluffyList needs camera access to scan recipes. You can enable it in Settings.")
            }
    }

    /// The three transient overlays (extraction spinner, extraction
    /// success, grocery-added confirmation).
    private func withOverlays<V: View>(_ content: V) -> some View {
        content
            .overlay { extractionOverlay }
            .overlay { successOverlay }
            .overlay { groceryAddedOverlay }
    }

    // MARK: - Photo Block

    private var photoBlock: some View {
        Group {
            if let image = viewModel.sourceImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()

                    Button {
                        viewModel.sourceImage = nil
                        viewModel.sourceImageRemoved = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(12)
                }
            } else if let path = viewModel.sourceImagePath,
                      let url = SupabaseManager.shared.publicStorageURL(path: path) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        default:
                            Color.fluffyDivider
                                .frame(height: 200)
                        }
                    }

                    Button {
                        viewModel.sourceImagePath = nil
                        viewModel.sourceImageRemoved = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.5))
                    }
                    .padding(12)
                }
            } else {
                Button {
                    showingPhotoLibrary = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28))
                        Text("Add Recipe Photo")
                            .font(.fluffyCallout)
                    }
                    .foregroundStyle(Color.fluffyTertiary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Scan Block

    private var scanBlock: some View {
        Button {
            showingPhotoOptions = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.fluffyHeadline)
                Text("Scan from Photo")
                    .font(.fluffyButton)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.fluffyCaption)
                    .foregroundStyle(Color.fluffyTertiary)
            }
            .foregroundStyle(Color.fluffyAmber)
            .padding(16)
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isExtracting || isImportingFromURL)
        .padding(.horizontal, 20)
    }

    private var urlImportBlock: some View {
        Button {
            showingURLImport = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link")
                    .font(.fluffyHeadline)
                Text("Import from URL")
                    .font(.fluffyButton)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.fluffyCaption)
                    .foregroundStyle(Color.fluffyTertiary)
            }
            .foregroundStyle(Color.fluffyAmber)
            .padding(16)
            .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isExtracting || isImportingFromURL)
        .padding(.horizontal, 20)
    }

    // MARK: - Name

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recipe Name")
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffyTertiary)

            TextField("e.g. Grandma's Chicken Soup", text: $viewModel.name)
                .font(.fluffyTitle)
                .foregroundStyle(Color.fluffyPrimary)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.fluffyDivider)
                        .frame(height: 1)
                }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Category")
                .font(.fluffyCaption)
                .foregroundStyle(Color.fluffyTertiary)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RecipeCategory.allCases) { cat in
                        Button {
                            viewModel.category = cat
                        } label: {
                            Text(cat.rawValue)
                                .font(.fluffySubheadline)
                                .foregroundStyle(
                                    viewModel.category == cat ? .white : Color.fluffyAmber
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    viewModel.category == cat
                                        ? Color.fluffyAmber
                                        : Color.fluffyAmber.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            FluffySectionHeader(title: "Details")
                .padding(.bottom, 14)

            detailRow(icon: "person.2", label: "Servings") {
                Stepper("\(viewModel.servings)", value: $viewModel.servings, in: 1...20)
                    .font(.fluffyCallout)
            }

            Rectangle().fill(Color.fluffyDivider).frame(height: 1)
                .padding(.vertical, 10)

            detailRow(icon: "clock", label: "Prep Time") {
                Stepper("\(viewModel.prepTimeMinutes) min", value: $viewModel.prepTimeMinutes, in: 0...480, step: 5)
                    .font(.fluffyCallout)
            }

            Rectangle().fill(Color.fluffyDivider).frame(height: 1)
                .padding(.vertical, 10)

            detailRow(icon: "flame", label: "Cook Time") {
                Stepper("\(viewModel.cookTimeMinutes) min", value: $viewModel.cookTimeMinutes, in: 0...480, step: 5)
                    .font(.fluffyCallout)
            }
        }
        .padding(16)
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    private func detailRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffyAmber)
                .frame(width: 20)
            Text(label)
                .font(.fluffyBody)
                .foregroundStyle(Color.fluffyPrimary)
            Spacer()
            content()
        }
    }

    // MARK: - Ingredients Card

    private var ingredientsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Ingredients")

            ForEach($viewModel.ingredientRows) { $row in
                IngredientRowView(data: $row)
            }
            .onDelete { indexSet in
                viewModel.ingredientRows.remove(atOffsets: indexSet)
            }

            Button {
                viewModel.ingredientRows.append(IngredientFormData())
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle")
                    Text("Add Ingredient")
                }
                .font(.fluffyCallout)
                .foregroundStyle(Color.fluffyAmber)
            }
        }
        .padding(16)
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Preparation")

            ZStack(alignment: .topLeading) {
                if viewModel.instructions.isEmpty {
                    Text("Add cooking steps...")
                        .font(.fluffyBody)
                        .foregroundStyle(Color.fluffyTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $viewModel.instructions)
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyPrimary)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Notes Card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Notes")

            TextField(
                "e.g. kids loved this, add more garlic next time",
                text: $viewModel.notes,
                axis: .vertical
            )
            .font(.fluffyBody)
            .foregroundStyle(Color.fluffyPrimary)
            .lineLimit(3...6)
        }
        .padding(16)
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Source Card

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            FluffySectionHeader(title: "Source")

            Picker("Source", selection: $viewModel.sourceType) {
                Text("None").tag(RecipeSource?.none)
                ForEach(RecipeSource.allCases) { source in
                    Text(source.rawValue).tag(RecipeSource?.some(source))
                }
            }
            .pickerStyle(.menu)
            .tint(Color.fluffyAmber)

            if viewModel.sourceType != nil {
                TextField(viewModel.sourcePlaceholder, text: $viewModel.sourceDetail)
                    .font(.fluffyBody)
                    .foregroundStyle(Color.fluffyPrimary)
            }
        }
        .padding(16)
        .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
    }

    // MARK: - Edit Actions

    private var editActions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await addIngredientsToGroceryList() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "cart.badge.plus")
                    Text("Add Ingredients to Grocery List")
                }
                .font(.fluffyButton)
                .foregroundStyle(Color.fluffySlateBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.fluffySlateBlue, lineWidth: 1.5)
                )
            }
            .disabled(isAddingToGrocery || nonEmptyIngredientCount == 0)
            .opacity(nonEmptyIngredientCount > 0 ? 1 : 0.4)

            Button {
                showingDeleteConfirmation = true
            } label: {
                Text("Delete Recipe")
                    .font(.fluffyButton)
                    .foregroundStyle(Color.fluffyError)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var extractionOverlay: some View {
        if isExtracting {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(extractingPageCount > 1
                         ? "Reading recipe from \(extractingPageCount) pages..."
                         : "Reading recipe from photo...")
                        .font(.fluffyHeadline)
                    Text("This may take a few seconds")
                        .font(.fluffyCallout)
                        .foregroundStyle(Color.fluffySecondary)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    @ViewBuilder
    private var successOverlay: some View {
        if showingExtractionSuccess {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fluffySuccess)
                Text("Recipe saved")
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var groceryAddedOverlay: some View {
        if showingGroceryAddedConfirmation {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.fluffySuccess)
                Text("Groceries updated")
                    .font(.fluffyHeadline)
                    .foregroundStyle(Color.fluffyPrimary)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showingGroceryAddedConfirmation = false }
                }
            }
        }
    }

    // MARK: - Helpers

    private var nonEmptyIngredientCount: Int {
        viewModel.ingredientRows.filter {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    // MARK: - Actions

    /// Clean a pasted URL string of the most common copy-paste
    /// artifacts before validation. Idempotent and order-independent.
    ///
    /// Specifically:
    ///   1. Drop zero-width / invisible characters (ZWSP, ZWJ, BOM,
    ///      word joiner, object replacement) — these can sneak in
    ///      from rich-text sources like Notes or iMessage.
    ///   2. Convert non-breaking space (U+00A0) to a regular space
    ///      so step 5 catches it.
    ///   3. Strip surrounding ASCII or smart quotes — common when
    ///      the user pasted `"https://..."`.
    ///   4. Trim leading/trailing whitespace and newlines.
    ///   5. Drop any whitespace remaining inside the URL — real URLs
    ///      use %20 for spaces, so any literal whitespace at this
    ///      point is a copy artifact (e.g. line wrap).
    static func normalizeURLString(_ raw: String) -> String {
        var s = raw

        // 1. Invisible characters.
        let invisible: Set<Character> = [
            "\u{200B}", "\u{200C}", "\u{200D}", // ZWSP, ZWNJ, ZWJ
            "\u{FEFF}", "\u{2060}",             // BOM/ZWNBSP, word joiner
            "\u{FFFC}"                          // object replacement
        ]
        s.removeAll { invisible.contains($0) }

        // 2. Non-breaking space → regular space.
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")

        // 3. Strip surrounding quotes (ASCII + curly).
        let quoteChars: Set<Character> = [
            "\"", "'",
            "\u{201C}", "\u{201D}", // “ ”
            "\u{2018}", "\u{2019}"  // ‘ ’
        ]
        while let first = s.first, quoteChars.contains(first) { s.removeFirst() }
        while let last = s.last, quoteChars.contains(last)   { s.removeLast() }

        // 4. Standard trim.
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // 5. Remove any remaining whitespace inside the URL.
        s.removeAll { $0.isWhitespace || $0.isNewline }

        return s
    }

    private func importFromURL() async {
        // Normalize the pasted string before validating. Pasting from
        // Notes / iMessage / Safari can drag in non-breaking spaces,
        // zero-width joiners, smart quotes, embedded newlines, and
        // object replacement characters — none of which a stock
        // `trimmingCharacters(in: .whitespacesAndNewlines)` removes.
        let raw = importURL
        let normalized = Self.normalizeURLString(raw)

        #if DEBUG
        Logger.supabase.debug("URL import: raw=\"\(raw, privacy: .public)\" normalized=\"\(normalized, privacy: .public)\"")
        #endif

        guard !normalized.isEmpty else { return }

        // Infer a scheme if the user pasted a bare domain like
        // "whole30.com/recipe/foo" — common when copying from a
        // browser address bar that hides the scheme. We require at
        // least one dot to avoid prefixing nonsense.
        let withScheme: String
        if normalized.lowercased().hasPrefix("http://") ||
           normalized.lowercased().hasPrefix("https://") {
            withScheme = normalized
        } else if normalized.contains(".") {
            withScheme = "https://" + normalized
            Logger.supabase.info("URL import: prepended https:// to bare domain")
        } else {
            extractionError = "That doesn't look like a valid http(s) URL."
            showingExtractionError = true
            return
        }

        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, host.contains(".") else {
            extractionError = "That doesn't look like a valid http(s) URL."
            showingExtractionError = true
            return
        }

        Logger.supabase.info("URL import: starting for \(url.absoluteString)")
        isImportingFromURL = true
        defer { isImportingFromURL = false }

        do {
            let extracted = try await RecipeWebImporter.importRecipe(from: url)
            Logger.supabase.info("URL import: extracted \"\(extracted.name)\" with \(extracted.ingredients.count) ingredients")

            #if DEBUG
            // Log the raw extracted ingredient fields so we can tell
            // whether names are missing at the extraction step vs lost
            // during form population or rendering. Each line shows the
            // fields the form will consume: name / amount / unit and
            // the optional section / preparation notes.
            for (idx, ing) in extracted.ingredients.enumerated() {
                Logger.supabase.debug(
                    "URL import: extracted ingredient[\(idx)] name=\"\(ing.name, privacy: .public)\" amount=\"\(ing.amount, privacy: .public)\" unit=\"\(ing.unit, privacy: .public)\" section=\"\(ing.section ?? "nil", privacy: .public)\" preparation=\"\(ing.preparation ?? "nil", privacy: .public)\""
                )
            }
            #endif

            // Populate the form for review. Per Phase 1 spec, do NOT
            // auto-save — the user edits and taps Save themselves.
            // sourceDetail gets the URL so the saved recipe remembers
            // where it came from.
            viewModel.populateFrom(extracted, sourceType: .url)
            if viewModel.sourceDetail.isEmpty {
                // Use the scheme-prefixed string so the recipe remembers
                // a clickable URL even when the user pasted a bare domain.
                viewModel.sourceDetail = withScheme
            }

            #if DEBUG
            // After populateFrom, log what actually landed in the form's
            // ingredient rows. A blank `nameDisplay` here with text in
            // `extracted.ingredients[i].name` above means the folding
            // logic dropped the name. A blank here that matches a blank
            // extracted name means the extractor itself returned no
            // name. And if this log shows names but the UI still looks
            // empty, the problem is in the row's text rendering.
            for (idx, row) in viewModel.ingredientRows.enumerated() {
                let trimmed = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let nameState = trimmed.isEmpty
                    ? (row.name.isEmpty ? "empty" : "whitespace-only")
                    : "populated(\(row.name.count) chars)"
                Logger.supabase.debug(
                    "URL import: viewModel.ingredientRows[\(idx)] name=\"\(row.name, privacy: .public)\" nameState=\(nameState, privacy: .public) qty=\(row.quantity) unit=\(row.unit.rawValue, privacy: .public)"
                )
            }
            #endif

            // Close the URL sheet so the user sees the populated form.
            showingURLImport = false
            importURL = ""
        } catch let error as RecipeWebImporter.ImportError {
            Logger.supabase.error("URL import failed: \(error)")
            switch error {
            case .urlFetchFailed(let detail):
                extractionError = "Couldn't load that page: \(detail)"
            case .webpageEmpty:
                extractionError = "That page didn't return any readable content."
            case .noRecipeFound:
                extractionError = "Couldn't find a recipe at that URL."
            }
            showingExtractionError = true
        } catch let error as RecipeResponseParser.ParseError {
            Logger.supabase.error("URL import parse failed: \(error)")
            switch error {
            case .noRecipeFound:
                extractionError = "Couldn't find a recipe at that URL."
            case .decodingFailed:
                extractionError = "Got a response but couldn't parse the recipe. Try again."
            }
            showingExtractionError = true
        } catch {
            Logger.supabase.error("URL import failed: \(error)")
            extractionError = error.localizedDescription
            showingExtractionError = true
        }
    }

    private func saveRecipe() async {
        let success = await viewModel.save(recipeService: recipeService)
        if success {
            dismiss()
        }
    }

    private func deleteRecipe() async {
        guard let id = viewModel.recipeID else { return }
        let didDelete = await recipeService.deleteRecipe(id)
        if didDelete {
            dismiss()
        }
        // On failure, recipeService.errorMessage is set and the sheet
        // stays open so the user can see the recipe is still here.
    }

    private func addIngredientsToGroceryList() async {
        let inserts = viewModel.ingredientRows
            .filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            .compactMap { row -> GroceryItemInsert? in
                guard let householdID = SupabaseManager.shared.currentHouseholdID else {
                    return nil
                }
                return GroceryItemInsert(
                    householdID: householdID,
                    name: row.name.trimmingCharacters(in: .whitespaces),
                    quantity: row.quantity,
                    unit: row.unit.rawValue
                )
            }

        guard !inserts.isEmpty else { return }

        Logger.supabase.info("Recipe form: adding \(inserts.count) ingredient(s) to grocery list")
        isAddingToGrocery = true
        let success = await groceryService.addItems(inserts)
        isAddingToGrocery = false

        if success {
            withAnimation { showingGroceryAddedConfirmation = true }
        }
    }

    // MARK: - Photo Extraction

    private func extractRecipe(from images: [UIImage]) async {
        isExtracting = true
        extractingPageCount = images.count
        extractionError = nil

        Logger.supabase.info("Photo import: extractRecipe called with \(images.count) image(s)")

        do {
            let extracted = try await RecipeImageExtractor.extract(from: images)
            Logger.supabase.info("Photo import: got \"\(extracted.name)\" with \(extracted.ingredients.count) ingredients")

            viewModel.populateFrom(extracted, sourceType: .photo)

            // Duplicate guard for the extraction flow. We do an
            // authoritative DB lookup BEFORE save, because the silent
            // "return existing" behavior in addRecipe is appropriate
            // for manual entry but would discard the just-extracted
            // ingredients/instructions here.
            if let existing = await recipeService.findRecipeByName(viewModel.name) {
                Logger.supabase.info("Photo import: name \"\(viewModel.name)\" matches existing id=\(existing.id.uuidString) — prompting user")
                extractionDuplicateExisting = existing
                showingExtractionDuplicate = true
                isExtracting = false
                extractingPageCount = 0
                return
            }

            Logger.supabase.info("Photo import: auto-saving extracted recipe")
            let autoSaved = await viewModel.save(recipeService: recipeService)
            if autoSaved {
                Logger.supabase.info("Photo import: auto-save succeeded, dismissing")
                isExtracting = false
                extractingPageCount = 0
                withAnimation { showingExtractionSuccess = true }
                try? await Task.sleep(for: .milliseconds(1200))
                dismiss()
                return
            } else {
                Logger.supabase.error("Photo import: auto-save failed — user must save manually")
            }
        } catch let error as AnthropicClient.ClientError {
            Logger.supabase.error("Photo import failed: \(error)")
            switch error {
            case .networkError:
                extractionError = "Connection timed out. Please try again in a moment."
            case .httpError(let statusCode, _):
                extractionError = "Server error (\(statusCode)). Please try again."
            case .decodingError, .emptyResponse:
                extractionError = "Got a response but couldn't parse the recipe. Please try again."
            }
            showingExtractionError = true
        } catch let error as RecipeResponseParser.ParseError {
            Logger.supabase.error("Photo import parse failed: \(error)")
            switch error {
            case .noRecipeFound:
                extractionError = "Couldn't read this recipe — try a clearer photo."
            case .decodingFailed:
                extractionError = "Got a response but couldn't parse the recipe. Please try again."
            }
            showingExtractionError = true
        } catch {
            Logger.supabase.error("Photo import failed: \(error)")
            extractionError = error.localizedDescription
            showingExtractionError = true
        }

        isExtracting = false
        extractingPageCount = 0
    }

    // MARK: - Extraction-Duplicate Handlers

    /// User chose "Update Existing Recipe" after a photo import
    /// detected a name collision. Switches the form to edit mode
    /// pointing at the existing row (preserving notes / source detail
    /// / card image), then saves — so the existing recipe ends up
    /// with the just-extracted name, category, servings, times,
    /// instructions, and ingredients.
    private func applyExtractionAsUpdate(of existing: RecipeRow) async {
        Logger.supabase.info("Photo import: user chose Update Existing for id=\(existing.id.uuidString)")
        isExtracting = true
        defer {
            isExtracting = false
            extractingPageCount = 0
        }

        viewModel.switchToUpdate(of: existing)

        let success = await viewModel.save(recipeService: recipeService)
        guard success else {
            Logger.supabase.error("Photo import: update-existing save failed — leaving form open for manual retry")
            extractionDuplicateExisting = nil
            return
        }

        Logger.supabase.info("Photo import: update-existing succeeded, dismissing")
        extractionDuplicateExisting = nil
        withAnimation { showingExtractionSuccess = true }
        try? await Task.sleep(for: .milliseconds(1200))
        dismiss()
    }

    /// User chose "Create New Copy" after a photo import detected a
    /// name collision. Renames the form's recipe to a unique
    /// disambiguated name and inserts as a brand-new row.
    private func applyExtractionAsNewCopy() async {
        Logger.supabase.info("Photo import: user chose Create New Copy")
        isExtracting = true
        defer {
            isExtracting = false
            extractingPageCount = 0
        }

        let original = viewModel.name
        viewModel.name = disambiguatedRecipeName(for: original)
        Logger.supabase.info("Photo import: disambiguated \"\(original)\" -> \"\(self.viewModel.name)\"")

        let success = await viewModel.save(recipeService: recipeService)
        guard success else {
            Logger.supabase.error("Photo import: new-copy save failed — leaving form open for manual retry")
            extractionDuplicateExisting = nil
            return
        }

        Logger.supabase.info("Photo import: new-copy save succeeded, dismissing")
        extractionDuplicateExisting = nil
        withAnimation { showingExtractionSuccess = true }
        try? await Task.sleep(for: .milliseconds(1200))
        dismiss()
    }

    /// Pick a name like "Foo (Copy)" or "Foo (Copy 2)" that doesn't
    /// collide with anything in the local recipe cache. Falls back to
    /// a timestamp suffix if every "Copy N" up to 20 is taken — at
    /// that point the user has bigger naming problems than us.
    private func disambiguatedRecipeName(for baseName: String) -> String {
        let base = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalize = RecipeService.normalizedName
        let existingNorms = Set(recipeService.recipes.map { normalize($0.name) })

        let firstCandidate = "\(base) (Copy)"
        if !existingNorms.contains(normalize(firstCandidate)) { return firstCandidate }
        for n in 2...20 {
            let candidate = "\(base) (Copy \(n))"
            if !existingNorms.contains(normalize(candidate)) { return candidate }
        }
        return "\(base) (\(Int(Date().timeIntervalSince1970)))"
    }
}

// MARK: - URL Import Sheet

/// Compact sheet for pasting a recipe URL. Shows inline progress
/// while the import runs so the user gets feedback without losing
/// the input field. Dismissal is locked while importing.
private struct URLImportSheet: View {
    @Binding var url: String
    let isImporting: Bool
    let onImport: () -> Void
    let onCancel: () -> Void

    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Paste a recipe URL and we'll fill in the form for you to review.")
                    .font(.fluffyCallout)
                    .foregroundStyle(Color.fluffySecondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("https://...", text: $url)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.go)
                    .onSubmit { onImport() }
                    // The FluffyList palette is hex-locked to light-mode
                    // values (fluffyCard is #FFFFFF, fluffyPrimary is
                    // near-black). On iOS 26, a TextField inside a sheet
                    // inherits the environment's primary color for its
                    // entered text — so in system dark mode the text
                    // rendered ~white on a white card, appearing blank.
                    // `.foregroundStyle` on the TextField alone didn't
                    // win against that environment inheritance. Belt-
                    // and-braces here: set both the deprecated
                    // `.foregroundColor` (which UIKit's UITextField
                    // bridge honors for entered text) and the newer
                    // `.foregroundStyle`, and pin the whole sheet to
                    // light mode below since the palette doesn't adapt.
                    .font(.body)
                    .foregroundColor(Color.fluffyPrimary)
                    .foregroundStyle(Color.fluffyPrimary)
                    .tint(Color.fluffyAmber)
                    .padding(12)
                    .background(Color.fluffyCard, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.fluffyDivider, lineWidth: 1)
                    )
                    .focused($urlFieldFocused)
                    .disabled(isImporting)

                if isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Importing recipe…")
                            .font(.fluffyCallout)
                            .foregroundStyle(Color.fluffySecondary)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.fluffyBackground)
            .navigationTitle("Import from URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .disabled(isImporting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") { onImport() }
                        .disabled(
                            isImporting ||
                            url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                }
            }
            .onAppear { urlFieldFocused = true }
        }
        // The FluffyList palette is light-mode-only (all hex-fixed). If
        // the user has the system in dark mode, the sheet's ambient
        // colors drift and TextField text can render near-white on the
        // white card background. Pinning the sheet itself to light mode
        // keeps the palette and the text renderer in agreement.
        .preferredColorScheme(.light)
    }
}
