import SwiftUI

/// Original source images and family cooking photos are separate media roles.
/// Source images may contain an entire cookbook page: never crop them to fill.
struct RecipeCardImage: View {
    enum Role { case browse, source, family, legacyFamily }
    let recipe: RecipeRow
    let height: CGFloat
    var role: Role = .browse

    @State private var privateURL: URL?
    @State private var privateFailed = false

    private var usesPrivateCover: Bool { role != .source && role != .legacyFamily && recipe.familyCoverImagePath != nil }

    private var path: String? {
        switch role {
        case .browse: recipe.familyCoverImagePath ?? recipe.homemadeImagePath ?? recipe.sourceImagePath
        case .source: recipe.sourceImagePath
        case .family: recipe.familyCoverImagePath ?? recipe.homemadeImagePath
        case .legacyFamily: recipe.homemadeImagePath
        }
    }
    private var isSource: Bool {
        role == .source || (role == .browse && recipe.familyCoverImagePath == nil && recipe.homemadeImagePath == nil && recipe.sourceImagePath != nil)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.fluffyCard
                if let url = usesPrivateCover ? privateURL : SupabaseManager.shared.publicStorageURL(path: path) {
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
                    if usesPrivateCover && !privateFailed { ProgressView() }
                    else { placeholder(path == nil ? "No photo" : "Photo unavailable") }
                }
            }
        }
        .task(id: path) {
            privateURL = nil; privateFailed = false
            if usesPrivateCover, let path {
                do {
                    let signed = try await FamilyPhotoService().imageURL(path: path)
                    guard !Task.isCancelled else { return }
                    privateURL = signed
                }
                catch { privateFailed = true }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel(isSource ? "Original source image for \(recipe.name)" : "Photo for \(recipe.name)")
    }

    private func placeholder(_ label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: isSource ? "doc.text.image" : "fork.knife")
                .font(.system(size: height > 100 ? 32 : 20))
            if height > 100 { Text(label).font(.caption) }
        }
        .foregroundStyle(Color.fluffySecondary)
    }
}
