import SwiftUI

/// Original source images and family cooking photos are separate media roles.
/// Source images may contain an entire cookbook page: never crop them to fill.
struct RecipeCardImage: View {
    enum Role { case browse, source, family, legacyFamily, cookbook }
    let recipe: RecipeRow
    let height: CGFloat
    var role: Role = .browse
    var showsPlaceholder = true

    @State private var privateURL: URL?
    @State private var privateFailed = false

    private var usesPrivateCover: Bool {
        (role == .browse || role == .family) && recipe.familyCoverImagePath != nil
    }
    private var usesCookbook: Bool {
        role == .cookbook || ((role == .browse || role == .family) &&
            recipe.familyCoverImagePath == nil && recipe.homemadeImagePath == nil && recipe.cookbookImagePath != nil)
    }
    private var usesPrivateImage: Bool { usesPrivateCover || usesCookbook }

    private var path: String? {
        switch role {
        case .browse: recipe.familyCoverImagePath ?? recipe.homemadeImagePath ?? recipe.cookbookImagePath ?? recipe.sourceImagePath
        case .source: recipe.sourceImagePath
        case .family: recipe.familyCoverImagePath ?? recipe.homemadeImagePath ?? recipe.cookbookImagePath
        case .legacyFamily: recipe.homemadeImagePath
        case .cookbook: recipe.cookbookImagePath
        }
    }
    private var isSource: Bool {
        role == .source || (role == .browse && recipe.familyCoverImagePath == nil && recipe.homemadeImagePath == nil && recipe.cookbookImagePath == nil && recipe.sourceImagePath != nil)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.fluffyCard
                if let url = usesPrivateImage ? privateURL : SupabaseManager.shared.publicStorageURL(path: path) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable()
                                .aspectRatio(contentMode: isSource ? .fit : .fill)
                                .frame(width: geometry.size.width, height: height)
                                .clipped()
                        case .failure: placeholder("Photo unavailable")
                        default: ProgressView().accessibilityLabel("Loading photo")
                        }
                    }
                } else {
                    if usesPrivateImage && !privateFailed { ProgressView() }
                    else { placeholder(path == nil ? "No photo" : "Photo unavailable") }
                }
            }
        }
        .task(id: path) {
            privateURL = nil; privateFailed = false
            if usesPrivateImage, let path {
                do {
                    let signed = usesCookbook
                        ? try await CookbookPhotoService().imageURL(path: path)
                        : try await FamilyPhotoService().imageURL(path: path)
                    guard !Task.isCancelled else { return }
                    privateURL = signed
                }
                catch { privateFailed = true }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottomTrailing) {
            if role == .cookbook && height > 100 {
                Text("Cookbook photo").font(.caption2.weight(.medium))
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Color.fluffyBackground, in: Capsule())
                    .foregroundStyle(Color.fluffyPrimary).padding(8)
            }
        }
        .accessibilityLabel(isSource ? "Original source image for \(recipe.name)" : (usesCookbook ? "Cookbook photo for \(recipe.name)" : "Photo for \(recipe.name)"))
    }

    private func placeholder(_ label: String) -> some View {
        VStack(spacing: 8) {
            if showsPlaceholder {
            Image(systemName: isSource ? "doc.text.image" : "fork.knife")
                .font(.system(size: height > 100 ? 32 : 20))
            if height > 100 { Text(label).font(.caption) }
            }
        }
        .foregroundStyle(Color.fluffySecondary)
    }
}
