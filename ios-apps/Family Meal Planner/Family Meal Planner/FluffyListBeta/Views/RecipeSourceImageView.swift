import SwiftUI

/// A readable original: preserve the full page, with explicit accessible zoom controls.
struct RecipeSourceImageView: View {
    let recipe: RecipeRow
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical]) {
                    if let url = SupabaseManager.shared.publicStorageURL(path: recipe.sourceImagePath) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFit()
                                    .frame(width: geometry.size.width * zoom)
                                    .accessibilityLabel("Original recipe source")
                            case .failure:
                                ContentUnavailableView("Source image unavailable", systemImage: "doc.text.image", description: Text("Close and try again when connected."))
                            default: ProgressView("Loading original")
                            }
                        }
                    }
                }
            }
            .background(Color.fluffyBackground)
            .navigationTitle("Original Recipe Source")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button { zoom = max(1, zoom - 0.5) } label: { Label("Zoom out", systemImage: "minus.magnifyingglass") }
                        .disabled(zoom <= 1)
                    Spacer()
                    Text("\(Int(zoom * 100))%").monospacedDigit()
                    Spacer()
                    Button { zoom = min(4, zoom + 0.5) } label: { Label("Zoom in", systemImage: "plus.magnifyingglass") }
                        .disabled(zoom >= 4)
                }
            }
            .tint(Color.fluffyAccent)
        }
    }
}
