//
//  AddEditRecipeView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import os

/// Handles both adding a new recipe and editing an existing one.
/// When `recipeToEdit` is nil → add mode (form starts empty).
/// When `recipeToEdit` has a value → edit mode (form pre-populates).
struct AddEditRecipeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: RecipeFormViewModel
    @State private var coordinator = RecipeImportCoordinator()

    // Photo library — tied to the PhotosPicker modifier
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Creator name — fetched from iCloud on appear for new recipes.
    @AppStorage("currentUserName") private var currentUserName: String = ""
    @State private var creatorDisplayName: String? = nil

    init(recipeToEdit: Recipe? = nil) {
        self._viewModel = State(initialValue: RecipeFormViewModel(recipe: recipeToEdit))
    }

    var body: some View {
        NavigationStack {
            Form {
                RecipeBasicsSection(viewModel: viewModel, coordinator: coordinator)
                RecipeIngredientsSection(viewModel: viewModel)
                RecipeInstructionsSection(viewModel: viewModel)
                RecipeSourceSection(viewModel: viewModel)
            }
            .navigationTitle(viewModel.isEditing ? "Edit Recipe" : "New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { formToolbar }
            .modifier(ImportModifiers(
                viewModel: viewModel,
                coordinator: coordinator,
                selectedPhotoItem: $selectedPhotoItem
            ))
            .modifier(FeedbackOverlays(coordinator: coordinator))
            .modifier(ImportAlerts(viewModel: viewModel, coordinator: coordinator))
            .onAppear {
                if !viewModel.isEditing {
                    Task {
                        let iCloudName = await CloudKitSharingService.shared.fetchCurrentUserDisplayName()
                        creatorDisplayName = iCloudName ?? (currentUserName.isEmpty ? nil : currentUserName)
                    }
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var formToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                viewModel.save(to: modelContext, addedBy: creatorDisplayName)
                dismiss()
            }
            .disabled(!viewModel.validate())
        }
    }
}

// MARK: - Import Modifiers

/// Groups the sheet/cover/picker modifiers for import pathways.
/// Extracted to reduce body complexity for the Swift type-checker.
private struct ImportModifiers: ViewModifier {
    var viewModel: RecipeFormViewModel
    var coordinator: RecipeImportCoordinator
    @Binding var selectedPhotoItem: PhotosPickerItem?

    func body(content: Content) -> some View {
        content
            // Choose between camera and photo library
            .confirmationDialog("Add Photo", isPresented: Bindable(coordinator).showingPhotoOptions, titleVisibility: .visible) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        coordinator.showingPhotoOptions = false
                        coordinator.requestCameraAccess()
                    }
                }
                Button("Choose from Library") {
                    coordinator.showingPhotoOptions = false
                    coordinator.showingPhotoLibrary = true
                }
                Button("Cancel", role: .cancel) {
                    coordinator.showingPhotoOptions = false
                }
            }
            // Photo library picker
            .photosPicker(isPresented: Bindable(coordinator).showingPhotoLibrary, selection: $selectedPhotoItem, matching: .images)
            // Camera (UIImagePickerController wrapper)
            .fullScreenCover(isPresented: Bindable(coordinator).showingCamera) {
                CameraView { image in
                    if let image {
                        Logger.importPipeline.debug("First page captured, size: \(Int(image.size.width), privacy: .public)x\(Int(image.size.height), privacy: .public)")
                        coordinator.scannedPages = [image]
                    } else {
                        Logger.importPipeline.debug("Camera cancelled")
                    }
                    coordinator.showingCamera = false
                }
                .ignoresSafeArea()
            }
            // Present PhotoScanView reactively when scannedPages goes from
            // empty to non-empty. This is more reliable than onDismiss which
            // can race with state propagation, causing "0 pages scanned."
            .onChange(of: coordinator.scannedPages.count) { oldCount, newCount in
                if oldCount == 0 && newCount > 0 {
                    coordinator.showingPhotoScan = true
                }
            }
            // Multi-page scan review
            .sheet(isPresented: Bindable(coordinator).showingPhotoScan) {
                PhotoScanView(
                    initialPages: coordinator.scannedPages,
                    onDone: { images in
                        coordinator.showingPhotoScan = false
                        Task { await coordinator.extractRecipeFromImages(images, into: viewModel) }
                    },
                    onCancel: {
                        coordinator.showingPhotoScan = false
                        coordinator.scannedPages = []
                    }
                )
            }
            // When a photo is picked from the library, load it and extract
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await coordinator.extractRecipeFromImage(image, into: viewModel)
                    } else {
                        coordinator.extractionError = "Could not load the selected photo."
                        coordinator.showingExtractionError = true
                    }
                    selectedPhotoItem = nil
                }
            }
            // Recipe search sheet
            .sheet(isPresented: Bindable(coordinator).showingRecipeSearch) {
                RecipeSearchView { extracted, url in
                    coordinator.handleSearchResult(extracted, url: url, into: viewModel)
                }
            }
    }
}

// MARK: - Feedback Overlays

/// Loading spinner and success checkmark overlays.
private struct FeedbackOverlays: ViewModifier {
    var coordinator: RecipeImportCoordinator

    func body(content: Content) -> some View {
        content
            .overlay { extractionOverlay }
            .overlay { successOverlay }
    }

    @ViewBuilder
    private var extractionOverlay: some View {
        if coordinator.isExtractingRecipe {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(extractionMessage)
                        .font(.headline)
                    Text(extractionDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var extractionMessage: String {
        if coordinator.isExtractingFromURL {
            return "Importing recipe from URL..."
        } else if coordinator.scanPageCount > 1 {
            return "Reading recipe from \(coordinator.scanPageCount) pages..."
        } else {
            return "Reading recipe from photo..."
        }
    }

    private var extractionDetail: String {
        coordinator.scanPageCount > 1
            ? "Combining pages — this may take a few extra seconds"
            : "This may take a few seconds"
    }

    @ViewBuilder
    private var successOverlay: some View {
        if coordinator.showingExtractionSuccess {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Recipe extracted!")
                    .font(.headline)
            }
            .padding(24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .transition(.opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { coordinator.showingExtractionSuccess = false }
                }
            }
        }
    }
}

// MARK: - Import Alerts

/// Alert modifiers for errors, camera permission, and URL input.
private struct ImportAlerts: ViewModifier {
    var viewModel: RecipeFormViewModel
    var coordinator: RecipeImportCoordinator

    func body(content: Content) -> some View {
        content
            .alert("Couldn't Read Recipe", isPresented: Bindable(coordinator).showingExtractionError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(coordinator.extractionError ?? "Something went wrong. Please try again.")
            }
            .alert("Camera Access Required", isPresented: Bindable(coordinator).showingCameraPermissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("FluffyList needs camera access to scan recipes. You can enable it in Settings.")
            }
            .alert("Import from URL", isPresented: Bindable(coordinator).showingURLInput) {
                TextField("https://example.com/recipe", text: Bindable(coordinator).importURLText)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                Button("Import") {
                    Task { await coordinator.extractRecipeFromURL(into: viewModel) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Paste a link to a recipe page")
            }
    }
}

#Preview("Add Recipe") {
    AddEditRecipeView()
        .modelContainer(for: [Recipe.self, Ingredient.self, MealPlan.self], inMemory: true)
}
