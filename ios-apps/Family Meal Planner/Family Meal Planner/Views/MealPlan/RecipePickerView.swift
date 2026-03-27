//
//  RecipePickerView.swift
//  FluffyList
//
//  Created by David Albert on 2/8/26.
//

import SwiftUI
import CoreData

/// A sheet that lets the user pick a recipe to assign to a meal slot.
/// Presented when the user taps an empty (or filled) meal slot.
struct RecipePickerView: View {
    @FetchRequest(
        entity: CDRecipe.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \CDRecipe.name, ascending: true)]
    ) private var recipes: FetchedResults<CDRecipe>

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    /// Called with the selected recipe, then the sheet dismisses.
    let onRecipeSelected: (CDRecipe) -> Void

    var filteredRecipes: [CDRecipe] {
        if searchText.isEmpty { return Array(recipes) }
        return recipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredRecipes, id: \.self) { recipe in
                Button {
                    onRecipeSelected(recipe)
                    dismiss()
                } label: {
                    VStack(alignment: .leading) {
                        Text(recipe.name)
                            .font(.headline)
                        Text(recipe.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.fluffyBackground)
            .navigationTitle("Choose Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "No Recipes",
                        systemImage: "book",
                        description: Text("Add recipes first in the Recipes tab")
                    )
                }
            }
        }
    }
}

#Preview {
    let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
    RecipePickerView { recipe in
        print("Selected: \(recipe.name)")
    }
    .environment(\.managedObjectContext, context)
}
