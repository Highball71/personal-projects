import Foundation
import Supabase
import UIKit

/// Additive photo history. A failed load never enables a destructive legacy fallback.
@MainActor
final class FamilyPhotoService {
    private var client: SupabaseClient { SupabaseManager.shared.client }
    static let bucket = "family-recipe-photos"
    /// The recipe_family_photos caption CHECK limit (migration 020:
    /// `length(caption) <= 2000`).
    static let captionLimit = 2000

    /// `caption` cut to fit the DB check. Postgres length() counts
    /// Unicode code points, but Swift's String.count counts visible
    /// characters — one family emoji is 1 Character but 5 code
    /// points — so prefix(2000) alone could still be rejected. Keeps
    /// whole Characters (never splits an emoji) while the running
    /// code-point total stays within the limit.
    static func truncatedCaption(_ caption: String) -> String {
        var scalarCount = 0
        var end = caption.startIndex
        for index in caption.indices {
            let characterScalars = caption[index].unicodeScalars.count
            guard scalarCount + characterScalars <= captionLimit else { break }
            scalarCount += characterScalars
            end = caption.index(after: index)
        }
        return String(caption[..<end])
    }

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
        try await client.storage.from(Self.bucket).upload(path, data: data,
            options: FileOptions(contentType: "image/jpeg", upsert: false))
        // Truncate like update() does — the DB rejects captions over the limit.
        let photo = FamilyRecipePhoto(id: id, recipeID: recipe.id, householdID: recipe.householdID,
                                     imagePath: path, caption: Self.truncatedCaption(caption),
                                     createdAt: Date())
        do {
            let saved: [FamilyRecipePhoto] = try await client.from("recipe_family_photos")
                .insert(photo).select().execute().value
            guard saved.contains(where: { $0.id == id }) else { throw PhotoError.cannotSave }
        } catch {
            // Best-effort orphan cleanup; never change the original or previous family photo.
            try? await client.storage.from(Self.bucket).remove(paths: [path])
            throw error
        }
    }

    func imageURL(for photo: FamilyRecipePhoto) async throws -> URL {
        try await imageURL(path: photo.imagePath)
    }

    func update(_ photo: FamilyRecipePhoto, caption: String, archived: Bool) async throws {
        guard SupabaseManager.shared.currentHouseholdID == photo.householdID else { throw PhotoError.cannotSave }
        struct Update: Encodable { let caption: String; let is_archived: Bool }
        let saved: [FamilyRecipePhoto] = try await client.from("recipe_family_photos")
            .update(Update(caption: Self.truncatedCaption(caption), is_archived: archived))
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

    /// Signed display URL, reused from SignedURLCache while it has
    /// more than ten minutes left — scrolling never re-signs.
    func imageURL(path: String) async throws -> URL {
        let storage = client.storage.from(Self.bucket)
        return try await SignedURLCache.shared.url(bucket: Self.bucket, path: path) { expiresIn in
            try await storage.createSignedURL(path: path, expiresIn: expiresIn)
        }
    }

    enum PhotoError: Error { case cannotSave }
}
