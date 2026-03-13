//
//  RecipeImportCoordinator.swift
//  Family Meal Planner
//
//  Manages the import pipeline state: camera → scan → extract → populate form.
//  Coordinates between camera, photo library, URL import, and recipe search.

import SwiftUI
import AVFoundation

@Observable
final class RecipeImportCoordinator {

    // MARK: - Import state

    enum ImportState: Equatable {
        case idle
        case scanning
        case extracting
        case success
        case error(String)
    }

    var importState: ImportState = .idle

    // Photo scan state
    var scannedPages: [UIImage] = []
    var scanPageCount: Int = 0
    var showingCamera: Bool = false
    var showingPhotoScan: Bool = false
    var showingPhotoOptions: Bool = false
    var showingPhotoLibrary: Bool = false

    // URL import state
    var showingURLInput: Bool = false
    var importURLText: String = ""
    var isExtractingFromURL: Bool = false

    // Recipe search state
    var showingRecipeSearch: Bool = false

    // Camera permission state
    var showingCameraPermissionDenied: Bool = false

    // Extraction feedback
    var isExtractingRecipe: Bool = false
    var extractionError: String?
    var showingExtractionError: Bool = false
    var showingExtractionSuccess: Bool = false

    // MARK: - Camera

    func requestCameraAccess() {
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

    // MARK: - Photo extraction

    /// Send images to Claude API and populate the view model with the result.
    @MainActor
    func extractRecipeFromImages(_ images: [UIImage], into viewModel: RecipeFormViewModel) async {
        let pageCount = images.count
        print("[PhotoScan] Starting extraction of \(pageCount) page(s)...")
        isExtractingRecipe = true
        extractionError = nil
        scanPageCount = pageCount

        do {
            print("[PhotoScan] Sending \(pageCount) page(s) to Claude API...")
            let extracted = try await ClaudeAPIService.extractRecipe(from: images)
            print("[PhotoScan] Got response: \"\(extracted.name)\" with \(extracted.ingredients.count) ingredients")

            viewModel.populateFrom(extracted, sourceType: .photo)

            withAnimation { showingExtractionSuccess = true }
        } catch {
            print("[PhotoScan] Error: \(error)")
            extractionError = "Couldn't read this recipe \u{2014} try a clearer photo."
            showingExtractionError = true
        }

        isExtractingRecipe = false
        scanPageCount = 0
        scannedPages = []
        print("[PhotoScan] Extraction complete, loading indicator hidden")
    }

    /// Send a single image (from photo library).
    @MainActor
    func extractRecipeFromImage(_ image: UIImage, into viewModel: RecipeFormViewModel) async {
        await extractRecipeFromImages([image], into: viewModel)
    }

    // MARK: - URL extraction

    @MainActor
    func extractRecipeFromURL(into viewModel: RecipeFormViewModel) async {
        var urlString = importURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !urlString.isEmpty && !urlString.contains("://") {
            urlString = "https://" + urlString
        }

        guard let url = URL(string: urlString), url.scheme != nil, url.host != nil else {
            print("[URLImport] Invalid URL entered: \"\(importURLText)\"")
            extractionError = "That doesn't look like a valid URL. Check the link and try again."
            showingExtractionError = true
            return
        }

        print("[URLImport] User initiated import for: \(url.absoluteString)")
        isExtractingRecipe = true
        isExtractingFromURL = true
        extractionError = nil

        do {
            let extracted = try await ClaudeAPIService.extractRecipe(fromURL: url)

            viewModel.populateFrom(extracted, sourceURL: url.absoluteString, sourceType: .url)

            print("[URLImport] Form pre-filled successfully with \"\(extracted.name)\"")
            withAnimation { showingExtractionSuccess = true }
        } catch {
            print("[URLImport] Import failed — no form data changed, nothing saved")
            print("[URLImport] Error: \(error)")

            if let apiError = error as? ClaudeAPIService.APIError,
               case .noRecipeFound = apiError {
                extractionError = "Couldn't find a recipe on that page."
            } else {
                extractionError = "Couldn't read a recipe from that page. Try a different URL."
            }
            showingExtractionError = true
        }

        isExtractingRecipe = false
        isExtractingFromURL = false
    }

    // MARK: - Search result import

    @MainActor
    func handleSearchResult(_ extracted: ExtractedRecipe, url: URL, into viewModel: RecipeFormViewModel) {
        viewModel.populateFrom(extracted, sourceURL: url.absoluteString, sourceType: .url)
        withAnimation { showingExtractionSuccess = true }
    }
}
