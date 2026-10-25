import Foundation
import Supabase
import UIKit

/// Additive photo history. A failed load never enables a destructive legacy fallback.
@MainActor
final class FamilyPhotoService {
    private var client: SupabaseClient { SupabaseManager.shared.client }

    func photos(for recipe: RecipeRow) async throws -> [FamilyRecipePhoto] {
        try await client.from("recipe_family_photos").select()
            .eq("recipe_id", value: recipe.id.uuidString)
            .eq("household_id", value: recipe.householdID.uuidString)
            .order("created_at", ascending: false).execute().value
    }

    func add(_ image: UIImage, caption: String, to recipe: RecipeRow) async throws {
        guard SupabaseManager.shared.currentHouseholdID == recipe.householdID,
              let data = RecipeService.resizedForCardUpload(image).jpegData(compressionQuality: 0.8) else {
            throw PhotoError.cannotSave
        }
        let id = UUID()
        let path = "\(recipe.householdID.uuidString)/\(recipe.id.uuidString)/\(id.uuidString).jpg"
        // New family history uses a private bucket. Original cookbook storage is untouched.
        try await client.storage.from("family-recipe-photos").upload(path, data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: false))
        let photo = FamilyRecipePhoto(id: id, recipeID: recipe.id, householdID: recipe.householdID,
                                     imagePath: path, caption: caption, createdAt: Date())
        do {
            let saved: [FamilyRecipePhoto] = try await client.from("recipe_family_photos")
                .insert(photo).select().execute().value
            guard saved.contains(where: { $0.id == id }) else { throw PhotoError.cannotSave }
        } catch {
            // Best-effort orphan cleanup; never change the original or previous family photo.
            try? await client.storage.from("family-recipe-photos").remove(paths: [path])
            throw error
        }
    }

    func imageURL(for photo: FamilyRecipePhoto) async throws -> URL {
        try await client.storage.from("family-recipe-photos")
            .createSignedURL(path: photo.imagePath, expiresIn: 3600)
    }

    func update(_ photo: FamilyRecipePhoto, caption: String, archived: Bool) async throws {
        guard SupabaseManager.shared.currentHouseholdID == photo.householdID else { throw PhotoError.cannotSave }
        struct Update: Encodable { let caption: String; let is_archived: Bool }
        let saved: [FamilyRecipePhoto] = try await client.from("recipe_family_photos")
            .update(Update(caption: String(caption.prefix(2000)), is_archived: archived))
            .eq("id", value: photo.id.uuidString).eq("household_id", value: photo.householdID.uuidString)
            .select().execute().value
        guard saved.count == 1 else { throw PhotoError.cannotSave }
    }

    func setCover(_ photo: FamilyRecipePhoto?, for recipe: RecipeRow) async throws {
        guard SupabaseManager.shared.currentHouseholdID == recipe.householdID,
              photo == nil || (photo?.recipeID == recipe.id && photo?.householdID == recipe.householdID && photo?.isArchived == false)
        else { throw PhotoError.cannotSave }
        let saved: [RecipeRow] = try await client.from("recipes")
            .update(["family_cover_image_path": photo?.imagePath])
            .eq("id", value: recipe.id.uuidString).eq("household_id", value: recipe.householdID.uuidString)
            .select().execute().value
        guard saved.count == 1 else { throw PhotoError.cannotSave }
    }

    func imageURL(path: String) async throws -> URL {
        try await client.storage.from("family-recipe-photos").createSignedURL(path: path, expiresIn: 3600)
    }

    enum PhotoError: Error { case cannotSave }
}
