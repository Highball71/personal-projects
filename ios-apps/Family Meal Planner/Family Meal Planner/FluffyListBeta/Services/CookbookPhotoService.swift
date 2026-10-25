import Foundation
import Supabase
import UIKit

/// Optional book illustration, separate from the original scan and cooking history.
@MainActor
final class CookbookPhotoService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    static let bucket = "cookbook-recipe-photos"

    func save(_ image: UIImage, for recipe: RecipeRow) async throws {
        guard SupabaseManager.shared.currentHouseholdID == recipe.householdID,
              let data = RecipeService.resizedForCardUpload(image).jpegData(compressionQuality: 0.8)
        else { throw SaveError.cannotSave }
        let path = "\(recipe.householdID.uuidString)/\(recipe.id.uuidString)/\(UUID().uuidString).jpg"
        try await client.storage.from(Self.bucket).upload(path, data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: false))
        do {
            let saved: [RecipeRow] = try await client.from("recipes")
                .update(["cookbook_image_path": path])
                .eq("id", value: recipe.id.uuidString)
                .eq("household_id", value: recipe.householdID.uuidString)
                .select().execute().value
            guard saved.count == 1, saved.first?.cookbookImagePath == path else { throw SaveError.cannotSave }
        } catch {
            // The policy rejects cleanup if a committed recipe references this image,
            // including when the response was lost after a successful database write.
            try? await client.storage.from(Self.bucket).remove(paths: [path])
            throw error
        }
    }

    func imageURL(path: String) async throws -> URL {
        try await client.storage.from(Self.bucket).createSignedURL(path: path, expiresIn: 3600)
    }

    enum SaveError: Error { case cannotSave }
}
