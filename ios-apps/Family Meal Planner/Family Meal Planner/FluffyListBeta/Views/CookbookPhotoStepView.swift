import PhotosUI
import SwiftUI

/// The recipe has already been saved. Skipping this optional step never loses it.
struct CookbookPhotoStepView: View {
    let recipe: RecipeRow
    let isAfterScan: Bool
    let onFinish: () -> Void
    @EnvironmentObject private var recipeService: RecipeService
    @State private var image: UIImage?
    @State private var selection: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var saving = false
    @State private var loadingImage = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isAfterScan {
                        Label("Recipe saved", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.fluffyAccent)
                    }
                    Text("Does the book have a photo of this dish?")
                        .font(.custom(FluffyFace.bold, size: 28, relativeTo: .title2))
                    Text("Photograph the picture in the cookbook, or choose it from your library. This is optional—you can add it later.")
                        .font(.body).foregroundStyle(Color.fluffySecondary)
                    Text(recipe.name).font(.headline)
                    if let image {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .accessibilityLabel("Selected cookbook photo")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showingCamera = true } label: {
                            Label("Photograph the book’s picture", systemImage: "camera")
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                    PhotosPicker(selection: $selection, matching: .images) {
                        Label("Choose from library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                    if loadingImage { ProgressView("Loading photo") }
                    Text("Cookbook photo · Private to your household")
                        .font(.caption.weight(.semibold))
                    Text("Your original scan stays separate. Photos of food you cook belong in Family Photos.")
                        .font(.caption).foregroundStyle(Color.fluffySecondary)
                    if let source = recipe.sourceDetail, !source.isEmpty {
                        Text("Source: \(source)").font(.caption)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(Color.fluffyError).font(.body)
                            .accessibilityLabel("Photo not saved. \(errorMessage)")
                    }
                    Button { Task { await save() } } label: {
                        Text(saving ? "Saving photo…" : "Save cookbook photo")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
                            .foregroundStyle(.white)
                            .background(Color.fluffyButtonFill, in: RoundedRectangle(cornerRadius: 12))
                    }.disabled(image == nil || saving || loadingImage)
                    Button(isAfterScan ? "Skip for now" : "Cancel", action: onFinish)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }.padding(20).frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color.fluffyPrimary)
            .background(Color.fluffyBackground)
            .buttonStyle(.plain)
            .disabled(saving)
            .navigationTitle("Cookbook photo")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(saving)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { captured in
                    showingCamera = false
                    if let captured { image = captured; errorMessage = nil }
                }.ignoresSafeArea()
            }
            .task(id: selection) {
                guard let selection else { return }
                loadingImage = true
                defer { loadingImage = false }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self),
                          let decoded = UIImage(data: data) else { throw CookbookPhotoService.SaveError.cannotSave }
                    guard !Task.isCancelled else { return }
                    image = decoded
                    errorMessage = nil
                } catch {
                    guard !Task.isCancelled else { return }
                    errorMessage = "That photo couldn’t be opened. Choose another photo or skip for now."
                }
            }
        }
    }

    private func save() async {
        guard let image, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try await CookbookPhotoService().save(image, for: recipe)
            await recipeService.fetchRecipes()
            onFinish()
        } catch {
            errorMessage = "Your recipe is saved, but this photo couldn’t be attached. Your selection is still here so you can retry."
        }
    }
}
