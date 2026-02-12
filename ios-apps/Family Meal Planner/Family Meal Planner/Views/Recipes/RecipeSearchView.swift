//
//  RecipeSearchView.swift
//  Family Meal Planner
//
//  Search for recipes online by name, browse results from popular food
//  blogs, and import a selected recipe into the form.

import SwiftUI

/// Sheet that lets the user search for recipes by name, see results from
/// popular food blogs, and tap one to import it via the URL import pipeline.
struct RecipeSearchView: View {
    /// Called when a recipe is successfully imported. Passes the extracted
    /// recipe data and the source URL so the caller can populate the form.
    var onRecipeImported: (ExtractedRecipe, URL) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var hasSearched = false
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showingSearchError = false

    // Import state — tracks which result is currently being imported
    @State private var importingResultID: UUID?
    @State private var importError: String?
    @State private var showingImportError = false

    var body: some View {
        NavigationStack {
            List {
                // Search field and button at the top
                Section {
                    HStack {
                        TextField("Search for a recipe...", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(false)
                            .submitLabel(.search)
                            .onSubmit { performSearch() }

                        Button {
                            performSearch()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty || isSearching)
                    }
                }

                // Results
                if isSearching {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Searching...")
                            Spacer()
                        }
                    }
                } else if results.isEmpty && hasSearched {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No recipes found")
                                .font(.headline)
                            Text("Try different search terms.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                } else if !results.isEmpty {
                    Section("Results") {
                        ForEach(results) { result in
                            Button {
                                importRecipe(from: result)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(2)
                                        Text(result.siteName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if importingResultID == result.id {
                                        ProgressView()
                                    }
                                }
                            }
                            .disabled(importingResultID != nil)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Search Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Search Failed", isPresented: $showingSearchError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(searchError ?? "Something went wrong.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importError ?? "Couldn't read a recipe from that page.")
            }
        }
    }

    // MARK: - Actions

    private func performSearch() {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return }

        isSearching = true
        results = []
        hasSearched = false

        Task {
            do {
                let searchResults = try await RecipeSearchService.searchRecipes(query: query)
                results = searchResults
            } catch {
                searchError = error.localizedDescription
                showingSearchError = true
            }
            hasSearched = true
            isSearching = false
        }
    }

    private func importRecipe(from result: SearchResult) {
        guard importingResultID == nil else { return }
        importingResultID = result.id

        Task {
            do {
                let extracted = try await ClaudeAPIService.extractRecipe(fromURL: result.url)
                // Success — call back to the parent and dismiss
                onRecipeImported(extracted, result.url)
                dismiss()
            } catch {
                if let apiError = error as? ClaudeAPIService.APIError,
                   case .noRecipeFound = apiError {
                    importError = "Couldn't find a recipe on that page."
                } else {
                    importError = "Couldn't read a recipe from that page. Try a different result."
                }
                showingImportError = true
            }
            importingResultID = nil
        }
    }
}

#Preview {
    RecipeSearchView { recipe, url in
        print("Imported: \(recipe.name) from \(url)")
    }
}
