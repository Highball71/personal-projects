//
//  SupabaseAddRecipeView.swift
//  FluffyList
//
//  Full recipe creation and editing form backed by Supabase.
//  Supports manual entry and photo import (camera → Claude Vision API).
//
//  Reuses existing shared components:
//    - IngredientRowView / IngredientFormData (ingredient row UI)
//    - CameraView / PhotoScanView (photo capture + multi-page review)
//    - RecipeImageExtractor (Claude Vision API pipeline)
//    - CameraPermissionService (camera permission handling)
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
    @State private var showingPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    /// Identifiable wrapper that drives .sheet(item:). The sheet content
    /// closure CANNOT fire until this is non-nil, so PhotoScanView can
    /// never be constructed with empty pages.
    @State private var scanSession: ScanSession?
    @State private var isExtracting = false
    @State private var extractingPageCount: Int = 0
    @State private var extractionError: String?
    @State private var showingExtractionError = false
    @State private var showingCameraPermissionDenied = false
    @State private var showingExtractionSuccess = false

    /// Wraps the captured pages with a fresh identity for each scan.
    /// Using .sheet(item:) guarantees SwiftUI doesn't pre-construct the
    /// sheet content while the data source is nil.
    private struct ScanSession: Identifiable {
        let id = UUID()
        let pages: [UIImage]
    }

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

                if viewModel.isEditing {
                    Section {
                        Button {
                            Task { await addIngredientsToGroceryList() }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Add Ingredients to Grocery List", systemImage: "cart.badge.plus")
                                Spacer()
                            }
                        }
                        .disabled(isAddingToGrocery || nonEmptyIngredientCount == 0)
                    }

                    Section {
                        Button("Delete Recipe", role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? "Edit Recipe" : "New Recipe")
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
            .alert("Delete this recipe?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    Task { await deleteRecipe() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
            // Photo option sheet (camera vs library)
            .confirmationDialog("Add Photo", isPresented: $showingPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        showingPhotoOptions = false
                        requestCameraAccess()
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
            // Camera. The capture handoff builds a ScanSession directly
            // from the captured image, so the scan sheet only presents
            // once we have pages in hand — no eager view construction,
            // no stale @State timing window.
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    handleCameraCapture(image)
                }
                .ignoresSafeArea()
            }
            // Multi-page scan review. Using .sheet(item:) so the content
            // closure only runs when scanSession is non-nil — this prevents
            // any eager view construction with empty pages.
            .sheet(item: $scanSession) { session in
                PhotoScanView(
                    initialPages: session.pages,
                    onDone: { images in
                        Logger.supabase.info("Photo import: PhotoScanView onDone with \(images.count) image(s)")
                        scanSession = nil
                        Task { await extractRecipe(from: images) }
                    },
                    onCancel: {
                        Logger.supabase.info("Photo import: PhotoScanView cancelled")
                        scanSession = nil
                    }
                )
                .onAppear {
                    Logger.supabase.info("Photo import: PhotoScanView appeared with session pages count=\(session.pages.count)")
                }
            }
            // Photo library selection
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await extractRecipe(from: [image])
                    } else {
                        extractionError = "Could not load the selected photo."
                        showingExtractionError = true
                    }
                    selectedPhotoItem = nil
                }
            }
            // Extraction error alert
            .alert("Couldn't Read Recipe", isPresented: $showingExtractionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(extractionError ?? "Something went wrong. Please try again.")
            }
            // Camera permission alert
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
            // Extraction loading overlay
            .overlay { extractionOverlay }
            // Success overlay
            .overlay { successOverlay }
            // Grocery added overlay
            .overlay { groceryAddedOverlay }
        }
    }

    // MARK: - Recipe Info

    private var recipeInfoSection: some View {
        Section("Recipe Info") {
            TextField("Recipe Name", text: $viewModel.name)

            Button {
                showingPhotoOptions = true
            } label: {
                Label("Scan from Photo", systemImage: "camera.fill")
            }
            .disabled(isExtracting)

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

    @ViewBuilder
    private var successOverlay: some View {
        if showingExtractionSuccess {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Recipe saved")
                    .font(.headline)
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
                    .foregroundStyle(.green)
                Text("Groceries updated")
                    .font(.headline)
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

    /// Number of ingredient rows with a non-blank name. Used to gate the
    /// "Add to Grocery List" button so we don't insert empty rows.
    private var nonEmptyIngredientCount: Int {
        viewModel.ingredientRows.filter {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
        }.count
    }

    // MARK: - Actions

    private func saveRecipe() async {
        let success = await viewModel.save(recipeService: recipeService)
        if success {
            dismiss()
        }
    }

    private func deleteRecipe() async {
        guard let id = viewModel.recipeID else { return }
        await recipeService.deleteRecipe(id)
        dismiss()
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

    // MARK: - Camera Permission

    private func requestCameraAccess() {
        switch CameraPermissionService.checkStatus() {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            Task {
                let granted = await CameraPermissionService.requestAccess()
                if granted {
                    showingCamera = true
                } else {
                    showingCameraPermissionDenied = true
                }
            }
        case .denied, .restricted:
            showingCameraPermissionDenied = true
        @unknown default:
            showingCameraPermissionDenied = true
        }
    }

    // MARK: - Camera Capture Handoff

    /// Handle the raw image from CameraView. Dismisses the camera cover,
    /// then atomically creates a ScanSession to drive .sheet(item:).
    /// The session is constructed with the captured image already in hand,
    /// so PhotoScanView cannot be initialized with empty pages.
    private func handleCameraCapture(_ image: UIImage?) {
        Logger.supabase.info("Photo import: camera captured image=\(image != nil)")

        showingCamera = false

        guard let image else {
            Logger.supabase.info("Photo import: camera cancelled, not presenting scan sheet")
            return
        }

        // Wait for the fullScreenCover dismiss animation to complete before
        // presenting the sheet. The ScanSession is constructed inline so
        // there's no intermediate state the sheet could read before the
        // image is available.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            let session = ScanSession(pages: [image])
            Logger.supabase.info("Photo import: opening scan sheet with session id=\(session.id.uuidString) pages=\(session.pages.count)")
            scanSession = session
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

            // Auto-save the extracted recipe so the user can't forget.
            // On success, show the "Recipe saved" toast briefly and
            // dismiss back to the list so the new recipe is immediately
            // visible. On failure, stay in add mode — the existing
            // inline error banner surfaces the problem and the user
            // can tap Save manually to retry.
            Logger.supabase.info("Photo import: auto-saving extracted recipe")
            let autoSaved = await viewModel.save(recipeService: recipeService)
            if autoSaved {
                Logger.supabase.info("Photo import: auto-save succeeded, dismissing")
                isExtracting = false
                extractingPageCount = 0
                withAnimation { showingExtractionSuccess = true }
                // Give the toast a moment to be seen, then dismiss.
                try? await Task.sleep(for: .milliseconds(1200))
                dismiss()
                return
            } else {
                Logger.supabase.error("Photo import: auto-save failed — user must save manually")
                // viewModel.saveError is already set; the form's
                // inline error section will show it. No extra UI.
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
}
