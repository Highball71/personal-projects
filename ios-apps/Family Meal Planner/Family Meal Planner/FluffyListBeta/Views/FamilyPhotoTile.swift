import SwiftUI

struct FamilyPhotoTile: View {
    let photo: FamilyRecipePhoto
    @State private var url: URL?
    @State private var failed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The card fixes the tile's size and the photo fills it,
            // cropped — a fitted photo left gray bands above and below.
            Color.fluffyCard
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .overlay {
                    if let url {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image): image.resizable().scaledToFill()
                            case .failure:
                                Label("Photo unavailable", systemImage: "photo")
                                    .font(.caption).foregroundStyle(Color.fluffySecondary)
                            default: ProgressView()
                            }
                        }
                    } else if failed {
                        Label("Photo unavailable", systemImage: "photo")
                            .font(.caption).foregroundStyle(Color.fluffySecondary)
                    } else { ProgressView() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            Text("Added \(photo.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption).foregroundStyle(Color.fluffySecondary)
            if !photo.caption.isEmpty { Text(photo.caption).font(.body) }
        }
        .task(id: photo.imagePath) {
            // A reused tile gets a new path: start clean, so the old
            // photo or an old failure never shows for the new one.
            url = nil
            failed = false
            do {
                let signed = try await FamilyPhotoService().imageURL(for: photo)
                guard !Task.isCancelled else { return }
                url = signed
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
        }
    }
}
