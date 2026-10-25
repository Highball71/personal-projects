import Foundation

/// A saved cooking photo. Added-at is upload time, never an inferred cooking date.
struct FamilyRecipePhoto: Codable, Identifiable, Equatable {
    let id: UUID
    let recipeID: UUID
    let householdID: UUID
    let imagePath: String
    let caption: String
    let createdAt: Date
    var isArchived: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, caption
        case isArchived = "is_archived"
        case recipeID = "recipe_id", householdID = "household_id"
        case imagePath = "image_path", createdAt = "created_at"
    }
}
